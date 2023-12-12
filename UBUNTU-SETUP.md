# Addendum: Installing Basic Dependencies for Ubuntu on Windows

This addendum to the original [Development Setup Guide](https://github.com/inaturalist/inaturalist/wiki/Development-Setup-Guide) is for developers using Ubuntu on Windows systems, either through the Windows Subsystem for Linux (WSL) or a virtual machine. The instructions here will help you set up your environment to run the iNaturalist web application and API. The addendum serves as a replacement for the original development setup guide's [Basic Dependencies](https://github.com/inaturalist/inaturalist/wiki/Development-Setup-Guide#basic-dependencies) section for Ubuntu users.

## Installing [Homebrew](https://brew.sh/)

1. Install Homebrew:

   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

## Installing [Docker](https://docs.docker.com/desktop/install/ubuntu/)

1. Docker prerequisite commands:

   ```bash
   # Install Gnome Terminal (for non-Gnome Desktop environments)
   sudo apt install gnome-terminal

   # Remove any previous installations of Docker Desktop.
   sudo apt remove docker-desktop

   # For a complete cleanup, remove Docker Desktop configuration and data files
   rm -r $HOME/.docker/desktop
   sudo rm /usr/local/bin/com.docker.cli
   sudo apt purge docker-desktop
   ```
2. Set up Docker's package repository:

   ```bash
   # Add Docker's official GPG key:
   sudo apt-get update
   sudo apt-get install ca-certificates curl gnupg
   sudo install -m 0755 -d /etc/apt/keyrings
   curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
   sudo chmod a+r /etc/apt/keyrings/docker.gpg

   # Add the repository to Apt sources:
   echo \
    "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
   sudo apt-get update
   ```
3. Download latest [DEB package](https://desktop.docker.com/linux/main/amd64/docker-desktop-4.25.0-amd64.deb?utm_source=docker&utm_medium=webreferral&utm_campaign=docs-driven-download-linux-amd64).
4. Install the package (replace `<version>` and `<arch>` with their respective Docker Desktop version and architecture - as seen in downloaded file name):

   ```bash\
   sudo apt-get update
   sudo apt-get install ./docker-desktop-<version>-<arch>.deb
   ```

## Installing [RVM](https://github.com/rvm/ubuntu_rvm/blob/master/README.md)

1. Install RVM:

   ```bash
   # Install necessary properties for adding PPAs
   sudo apt-get install software-properties-common

   # Add the RVM PPA and install RVM
   sudo apt-add-repository -y ppa:rael-gc/rvm
   sudo apt-get update
   sudo apt-get install rvm

   # Add the current user to the rvm group
   sudo usermod -a -G rvm $USER

   # Load RVM into a shell session automatically on startup
   echo 'source "/etc/profile.d/rvm.sh"' >> ~/.bashrc
   ```
2. Reboot system!

## Installing [NVM](https://github.com/nvm-sh/nvm#installing-and-updating)

1. Install NVM:

   ```bash
   curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
   ```

For the rest of the development setup, use the original Development Setup Guide, continuing from the [Rails app](https://github.com/inaturalist/inaturalist/wiki/Development-Setup-Guide#rails-app) section.

## Summary

This guide provides step-by-step instructions tailored for setting up the iNaturalist development environment on Ubuntu for Windows. Following these instructions should enable a smooth setup process and prepare your system for iNaturalist development tasks.
