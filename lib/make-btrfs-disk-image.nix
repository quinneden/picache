{
  config,
  pkgs,
  bootFromBTRFS ? true,
  BTRFSDupData ? false,
  subvolumes ? [
    "@"
    "@boot"
    "@gnu"
    "@home"
    "@nix"
    "@snapshots"
    "@var"
  ],
}:
let
  extraConfigTxt = [
    "gpu_mem=16"
    "program_usb_boot_mode=1"
    "program_usb_boot_timeout=1"
    "arm_boost=1"
    "arm_64bit=1"
    "enable_uart=1"
  ];

  inherit (config.system.build) toplevel;
  channelSources =
    let
      nixpkgs = pkgs.lib.cleanSource pkgs.path;
    in
    pkgs.runCommand "nixos-${config.system.nixos.version}" { } ''
      mkdir -p $out
      cp -prd ${nixpkgs.outPath} $out/nixos
      chmod -R u+w $out/nixos
      if [ ! -e $out/nixos/nixpkgs ]; then
        ln -s . $out/nixos/nixpkgs
      fi
      rm -rf $out/nixos/.git
      echo -n ${config.system.nixos.versionSuffix} > $out/nixos/.version-suffix
    '';

  closure = pkgs.closureInfo {
    rootPaths = [
      toplevel
      channelSources
    ];
  };

  firmwarePartOpts =
    let
      opts = {
        inherit pkgs config;
        inherit (pkgs) lib;
      };
      inherit ((import (pkgs.path + "/nixos/modules/installer/sd-card/sd-image.nix") opts).options)
        sdImage
        ;
      sdImageAarch64 = import (pkgs.path + "/nixos/modules/installer/sd-card/sd-image-aarch64.nix");
    in
    {
      firmwarePartID = sdImage.firmwarePartitionID.default;
      firmwarePartName = sdImage.firmwarePartitionName.default;
      inherit ((sdImageAarch64 opts).sdImage) populateFirmwareCommands;

      inherit
        ((import (pkgs.path + "/nixos/modules/system/boot/loader/generic-extlinux-compatible") {
          inherit pkgs config;
          inherit (pkgs) lib;
        }).config.content.boot.loader.generic-extlinux-compatible
        )
        populateCmd
        ;
    };
in
assert pkgs.lib.assertMsg (
  !(bootFromBTRFS && BTRFSDupData)
) "bootFromBTRFS and BTRFSDupData are mutually exclusive";
pkgs.vmTools.runInLinuxVM (
  pkgs.runCommand "btrfs-image"
    {
      enableParallelBuildingByDefault = true;
      nativeBuildInputs = with pkgs; [
        btrfs-progs
        dosfstools
        e2fsprogs
        git # initialize repo at `/etc/nixos`
        nix # mv, cp
        util-linux # sfdisk
        config.system.build.nixos-install
      ];

      preVM = ''
        ${pkgs.vmTools.qemu}/bin/qemu-img create -f raw nixos.img 5G
      '';
      postVM = ''
        mkdir -p $out
        mv nixos.img $out
      '';
      memSize = 4096;
      QEMU_OPTS =
        "-drive "
        + builtins.concatStringsSep "," [
          "file=nixos.img"
          "format=raw"
          "if=virtio"
          "cache=unsafe"
          "werror=report"
        ];
    }
    ''

      # NB: Don't set -f, as some of the builtin nix stuff depends on globbing
      set -Eeu -o pipefail
      set -x

      shrinkBTRFSFs() {
        local mpoint shrinkBy
        mpoint=''${1:-/mnt}

        while :; do
          shrinkBy=$(
            btrfs filesystem usage -b "$mpoint" |
            awk \
              -v fudgeFactor=0.9 \
              -F'[^0-9]' \
              '
                /Free.*min:/ {
                  sz = $(NF-1) * fudgeFactor
                  print int(sz)
                  exit
                }
              '
          )
          btrfs filesystem resize -"$shrinkBy" "$mpoint" || break
        done
        btrfs scrub start -B "$mpoint"
      }

      shrinkLastPartition() {
        local blockDev sizeInK partNum

        blockDev=''${1:-/dev/vda}
        sizeInK=$2

        partNum=$(
          lsblk --paths --list --noheadings --output name,type "$blockDev" |
            awk \
              -v blockdev="$blockDev" \
              '
                # Assume lsblk has output these in order, get the name of
                # last device it identifies as a partition
                $2 == "part" {
                  partname = $1
                }

                # Strip out the blockdev so we get just partition number
                END {
                    gsub(blockdev, "", partname)
                    print partname
                }
              '
        )

        echo ",$sizeInK" | sfdisk -N"$partNum" "$blockDev"
        ${pkgs.systemd}/bin/udevadm settle
      }

      ${pkgs.kmod}/bin/modprobe btrfs
      ${pkgs.systemd}/lib/systemd/systemd-udevd &

      # Gap before first partition
      gap=1

      firmwareSize=512
      firmwareSizeBlocks=$(( $firmwareSize * 1024 * 1024 / 512 ))

      # type=b is 'W95 FAT32', 83 is 'Linux'.
      # The "bootable" partition is where u-boot will look file for the bootloader
      # information (dtbs, extlinux.conf file).
      # Setting the bootable flag on the btrfs partition allows booting directly

      fatBootable=
      BTRFSBootable=bootable
      if [ ! ${toString bootFromBTRFS} ]; then
        fatBootable=bootable
        BTRFSBootable=
      fi

      sfdisk /dev/vda <<EOF
        label: dos
        label-id: ${firmwarePartOpts.firmwarePartID}

        start=''${gap}M,size=$firmwareSizeBlocks, type=b, $fatBootable
        start=$(( $gap + $firmwareSize ))M, type=83, $BTRFSBootable
      EOF

      ${pkgs.systemd}/bin/udevadm settle

      # rpi firmware
      mkfs.vfat -n ${firmwarePartOpts.firmwarePartName} /dev/vda1

      # btrfs root
      mkfs.btrfs \
        --label nixos \
        --uuid "0e338732-3098-47ba-8f8a-f4b34400c189" \
        /dev/vda2

      ${pkgs.systemd}/bin/udevadm trigger
      ${pkgs.systemd}/bin/udevadm settle

      mkdir -p /mnt /btrfs /tmp/firmware

      btrfsopts=space_cache=v2,compress-force=zstd
      mount -t btrfs -o "$btrfsopts" /dev/disk/by-label/nixos /btrfs
      btrfs filesystem resize max /btrfs

      for sv in ${toString subvolumes}; do
        btrfs subvolume create /btrfs/"$sv"

        dest="/mnt/''${sv#@}"
        if [[ "$sv" = "@snapshots" ]]; then
          dest=/mnt/.snapshots
        fi
        mkdir -p "$dest"
        mount -t btrfs -o "$btrfsopts,subvol=$sv" /dev/disk/by-label/nixos "$dest"
      done
      mkdir -p /mnt/boot/firmware

      # All subvols should now be properly mounted at /mnt
      umount -R /btrfs

      # Enabling compression on /boot prevents uboot from booting directly from
      # BTRFS for some reason. Instead of `chattr +C` could also use
      # `btrfs property set /mnt/boot compression none` but this gets overridden by
      # the `compress-force=zstd` (as opposed to `compress=zstd`) option
      chattr +C /mnt/boot

      # Populate firmware files into FIRMWARE partition
      mount /dev/disk/by-label/${firmwarePartOpts.firmwarePartName} /tmp/firmware
      ${firmwarePartOpts.populateFirmwareCommands}

      echo "${pkgs.lib.concatStringsSep "\n" extraConfigTxt}" >> /tmp/firmware/config.txt

      if [ ${toString bootFromBTRFS} ]; then
        bootDest=/mnt/boot
      else
        bootDest=/tmp/firmware
      fi

      ${firmwarePartOpts.populateCmd} -c ${toplevel} -d "$bootDest" -g 0

      export NIX_STATE_DIR=$TMPDIR/state
      nix-store < ${closure}/registration \
        --load-db \
        --option build-users-group ""

      cp ${closure}/registration /mnt/nix-path-registration

      echo "running nixos-install..."
      nixos-install \
        --max-jobs auto \
        --cores 0 \
        --root /mnt \
        --no-root-passwd \
        --no-bootloader \
        --substituters "" \
        --option build-users-group "" \
        --system ${toplevel}

      # Disable automatic creation of a default nix channel
      # See also `nix-daemon.nix`
      mkdir -p /mnt/root
      touch /mnt/root/.nix-channels

      shrinkBTRFSFs /mnt

      local sizeInK
      sizeInK=$(
        btrfs filesystem usage -b /mnt |
        awk '/Device size:/ { print ($NF / 1024) "KiB" }'
      )

      umount -R /mnt /tmp/firmware

      shrinkLastPartition /dev/vda "$sizeInK"
      btrfs check /dev/disk/by-label/nixos
    ''
)
