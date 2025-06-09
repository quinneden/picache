{
  config,
  lib,
  pkgs,
  bootSize ? "512M",
  diskSize ? "auto",
  memSize ? 4096,
  name ? "picache-nixos-${lib.versions.majorMinor lib.version}-btrfs-image",
  uuid ? "FD3C6289-A02A-43B1-9399-86B7EB444980",
}:
let
  binPath = lib.makeBinPath (
    with pkgs;
    [
      btrfs-progs
      config.system.build.nixos-install
      coreutils
      dosfstools
      git
      gptfdisk
      lkl
      nix
      nixos-enter
      parted
      util-linux
    ]
    ++ stdenv.initialPath
  );

  blockSize = toString (4 * 1024); # ext4fs/btrfs block size (not block device sector size)

  closureInfo = pkgs.closureInfo {
    rootPaths = [ config.system.build.toplevel ];
  };

  fileName = "${name}.img";
  label = "nixos";

  prepareStagingRoot = ''
    export PATH=${binPath}:$PATH

    root="$PWD/root"
    mkdir -p $root

    export HOME=$TMPDIR

    # Provide a Nix database so that nixos-install can copy closures.
    export NIX_STATE_DIR=$TMPDIR/state
    nix-store --load-db < ${closureInfo}/registration

    chmod 755 "$TMPDIR"
    echo "running nixos-install..."
    nixos-install --root $root --no-bootloader --no-root-passwd \
      --system ${config.system.build.toplevel} \
      --no-channel-copy \
      --substituters ""

    touch $root/expand-on-first-boot
  '';

  partitionImage = ''
    sectorsToKilobytes() {
      echo $(( ( "$1" * 512 ) / 1024 ))
    }
    sectorsToBytes() {
      echo $(( "$1" * 512  ))
    }
    # Given lines of numbers, adds them together
    sum_lines() {
      local acc=0
      while read -r number; do
        acc=$((acc+number))
      done
      echo "$acc"
    }
    mebibyte=$(( 1024 * 1024 ))
    # Approximative percentage of reserved space in an ext4 fs over 512MiB.
    # 0.05208587646484375 × 1000, integer part: 52
    compute_fudge() {
      echo $(( $1 * 52 / 1000 ))
    }
    round_to_nearest() {
      echo $(( ( $1 / $2 + 1) * $2 ))
    }

    mkdir $out

    diskImage=nixos.raw

    bootSize=$(round_to_nearest $(numfmt --from=iec '${bootSize}') $mebibyte)
    bootSizeMiB=$(( bootSize / 1024 / 1024 ))MiB

    ${
      if diskSize == "auto" then
        ''
          # Add the GPT at the end
          gptSpace=$(( 512 * 34 * 1 ))
          # Normally we'd need to account for alignment and things, if bootSize
          # represented the actual size of the boot partition. But it instead
          # represents the offset at which it ends.
          # So we know bootSize is the reserved space in front of the partition.
          reservedSpace=$(( gptSpace + bootSize ))

          # Compute required space in filesystem blocks
          diskUsage=$(find . ! -type d -print0 | du --files0-from=- --apparent-size --count-links --block-size "${blockSize}" | cut -f1 | sum_lines)
          # Each inode takes space!
          numInodes=$(find . | wc -l)
          # Convert to bytes, inodes take two blocks each!
          diskUsage=$(( (diskUsage + 2 * numInodes) * ${blockSize} ))
          # Then increase the required space to account for the reserved blocks.
          fudge=$(compute_fudge $diskUsage)
          requiredFilesystemSpace=$(( diskUsage + fudge ))

          # Round up to the nearest block size.
          # This ensures whole $blockSize bytes block sizes in the filesystem
          # and helps towards aligning partitions optimally.
          requiredFilesystemSpace=$(round_to_nearest $requiredFilesystemSpace ${blockSize})

          diskSize=$(( requiredFilesystemSpace + reservedSpace ))

          # Round up to the nearest mebibyte.
          # This ensures whole 512 bytes sector sizes in the disk image
          # and helps towards aligning partitions optimally.
          diskSize=$(round_to_nearest $diskSize $mebibyte)

          truncate -s "$diskSize" $diskImage

          printf "Automatic disk size...\n"
          printf "  Closure space use: %d bytes\n" $diskUsage
          printf "  fudge: %d bytes\n" $fudge
          printf "  Filesystem size needed: %d bytes\n" $requiredFilesystemSpace
          printf "  Additional space: %d bytes\n" $reservedSpace
          printf "  Disk image size: %d bytes\n" $diskSize
        ''
      else
        ''
          truncate -s ${toString diskSize}M $diskImage
        ''
    }

    parted --script $diskImage -- \
      mklabel gpt \
      mkpart ESP fat32 8MiB $bootSizeMiB \
      set 1 boot on \
      align-check optimal 1 \
      mkpart primary btrfs $bootSizeMiB 100% \
      align-check optimal 2 \
      print

    sgdisk \
      --disk-guid=97FD5997-D90B-4AA3-8D16-C1723AEA73C \
      --partition-guid=1:1C06F03B-704E-4657-B9CD-681A087A2FDC \
      --partition-guid=2:${uuid} \
      $diskImage
  '';

  copyStagingRootToImage = ''
    export PATH=${binPath}:$PATH

    root=$PWD/root

    {
      cptofs -p -P 2 -t btrfs -i $diskImage $root/{etc,expand-on-first-boot} /@
      cptofs -p -P 2 -t btrfs -i $diskImage $root/nix/* /@nix
    } || (echo >&2 "ERROR: cptofs failed. diskSize might be too small for closure."; exit 1)

    mv $diskImage $out/nixos.raw
    diskImage=$out/nixos.raw
  '';

  buildImageStage1 = pkgs.vmTools.runInLinuxVM (
    pkgs.runCommand "${name}-stage1"
      {
        preVM = prepareStagingRoot + partitionImage;
        postVM = copyStagingRootToImage;
        inherit memSize;
      }
      ''
        export PATH=${binPath}:$PATH

        rootDisk=/dev/vda2

        mkfs.btrfs -U ${uuid} -L ${label} -s ${blockSize} $rootDisk

        mountPoint=/mnt
        mkdir $mountPoint
        mount $rootDisk $mountPoint

        btrfs filesystem resize max $mountPoint

        btrfs subvolume create $mountPoint/@
        btrfs subvolume create $mountPoint/@home
        btrfs subvolume create $mountPoint/@nix

        umount $mountPoint
      ''
  );

  moveImage = ''
    mkdir -p $out
    mv $diskImage $out/${fileName}
    diskImage=$out/${fileName}
  '';

  buildImageStage2 = pkgs.vmTools.runInLinuxVM (
    pkgs.runCommand name
      {
        preVM = ''
          install -m644 -t ./. ${buildImageStage1}/nixos.raw
          diskImage=nixos.raw
        '';
        postVM = moveImage;
        inherit memSize;
      }
      ''
        export PATH=${binPath}:$PATH

        rootDisk=/dev/vda2

        # make systemd-boot find ESP without udev
        mkdir /dev/block
        ln -s /dev/vda1 /dev/block/254:1

        mountPoint=/mnt
        mkdir $mountPoint

        mount -o compress=zstd,subvol=@ $rootDisk $mountPoint
        mkdir -p $mountPoint/{home,nix}

        mount -o compress=zstd,subvol=@home $rootDisk $mountPoint/home
        mount -o compress=zstd,noatime,subvol=@nix $rootDisk $mountPoint/nix

        mkdir -p /mnt/boot
        mkfs.vfat -n ESP /dev/vda1
        mount /dev/vda1 /mnt/boot

        cp -r ${pkgs.rpi4-uefi-firmware-images}/* /mnt/boot
        chmod -R +w /mnt/boot/*

        export HOME=$TMPDIR
        NIXOS_INSTALL_BOOTLOADER=1 nixos-enter --root $mountPoint -- /nix/var/nix/profiles/system/bin/switch-to-configuration boot

        umount -R /mnt
      ''
  );
in
buildImageStage2
