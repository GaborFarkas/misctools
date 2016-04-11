# archive.sh

Linux tool for archiving a set of directories with their content at every shutdown.

It creates gzipped archives, and updates them if a change is detected.

LSB Init Script compliant, thus it can be used with `update-rc.d`.

##Installation

1. Copy the config file into `/etc/archive`.
``` bash
sudo mkdir /etc/archive && cp archive.conf /etc/archive
```
2. Copy to the script to `/etc/init.d`.
``` bash
sudo cp archive.sh /etc/init.d
```
3. Give the script run privilege.
``` bash
sudo chmod +x /etc/init.d/archive.sh
```
4. Run `update-rc.d` to activate the script.
``` bash
sudo update-rc.d archive.sh defaults
```

##Uninstallation

1. Deactivate the script with `update-rc.d`.
``` bash
sudo update-rc.d -f archive.sh remove
```
2. Optionally remove the script, and the configuration file.
``` bash
sudo rm -r /etc/archive && rm /etc/init.d/archive.sh
```

##Configuration

Edit `activate.conf` to configure the script. It currently accepts the following parameters:

- `ArchiveFolder`: An absolute path to a folder containing archive files. Takes precedence over `ArchiveDisk` and `MountPoint`.
- `ArchiveDisk`: A block device where archives can be found.
- `MountPoint`: An absolute path where `ArchiveDisk` should be mounted.
- A set of mappings: An absolute path of the sources followed by `->` followed by a relative path from the `MountPoint`. Example:
``` bash
/home/user/projects->/projects
```
In the relative path the first `/` is mandatory.
- `UpdateMode`: Tell the script whether existing archives should be updated. It must be an `On` value. It can take gradually more time, but it makes a safe (non-destroying) update.

Commented out lines (starting with a `#`) are not parsed by the script.

##Manual invoke

You can invoke the script manually any time by using the following command:

``` bash
sudo /etc/init.d/archive.sh stop
```
