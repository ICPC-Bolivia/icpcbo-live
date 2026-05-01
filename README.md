# ICPC Bolivia ISO

Repositorio para construir la ISO Debian personalizada del entorno ICPC Bolivia.

## Requisitos

Los comandos de build usan `debootstrap`, `chroot`, mounts y generación de ISO, por eso deben ejecutarse en Linux y normalmente con `sudo`.

En Debian/Ubuntu instala:

```bash
sudo apt update
sudo apt install -y \
  bash \
  ca-certificates \
  coreutils \
  curl \
  debootstrap \
  dosfstools \
  file \
  gdisk \
  grub-common \
  grub-pc-bin \
  grub-efi-amd64-bin \
  initramfs-tools \
  kmod \
  mtools \
  rsync \
  squashfs-tools \
  systemd-sysv \
  xorriso \
  xz-utils \
  zstd
```

Para usar el cache local de APT:

```bash
sudo apt install -y docker.io docker-compose-plugin
sudo systemctl enable --now docker
```

Para probar la ISO con VM desde `start.sh`:

```bash
sudo apt install -y \
  qemu-system-x86 \
  qemu-utils \
  virtinst \
  libvirt-daemon-system \
  libvirt-clients \
  libguestfs-tools
```

## Configuración

La configuración central está en:

```text
config/iso.conf
```

## Build

Construir la ISO completa:

```bash
sudo ./start.sh build
```

Construir y levantar la VM de prueba:

```bash
sudo ./start.sh build-run
```

