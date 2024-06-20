# Testin ScanImageTiffReader Matlab Package

## Error

>> reader=ScanImageTiffReader('/v-data4/foconnell/data/parent/raw/MH70_0p6mm_FOV_50_550um_depth_som_stim_199mW_3min_M1_00001_00001.tif');
>> x = reader.data()
Error using mexScanImageTiffData
Resource temporarily unavailable

Error in ScanImageTiffReader/data (line 99)
            stack=mexScanImageTiffData(obj.h_);

## Building Mex Files

foconnell at v-gpu2 in /v-data4/foconnell/repos/LBM-CaImAn-MATLAB/packages/scanimagetiffreader-matlab/src (dev●)
$ ./build_mex
Building with 'gcc'.
MEX completed successfully.
Building with 'gcc'.
MEX completed successfully.
Building with 'gcc'.
MEX completed successfully.
Building with 'gcc'.
MEX completed successfully.
Building with 'gcc'.
MEX completed successfully.
Building with 'gcc'.
MEX completed successfully.

## Testing scanimagetiffreader-matlab/src

```MATLAB
>> reader.metadata()

ans =

    'SI.LINE_FORMAT_VERSION = 1
     SI.TIFF_FORMAT_VERSION = 3
     SI.VERSION_COMMIT = '5ebac70274a5aea7cadb860425577774bea68615'
     SI.VERSION_MAJOR = '2018b'
     ...

>> reader.apiVersion()

ans =

    'Version 1.3-9c3423c by Vidrio Technologies <support@vidriotech.com>'

>> which ScanImageTiffReader
/v-data4/foconnell/repos/LBM-CaImAn-MATLAB/packages/scanimagetiffreader-matlab/src/ScanImageTiffReader.m  % ScanImageTiffReader constructor

```

## Testing Binary

```BASH
foconnell at v-gpu2 in /v-data4/foconnell/repos/LBM-CaImAn-MATLAB/packages/scanimagetiffreader-matlab/external/ScanImageTiffReader-1.3-Linux/bin (dev●)
$ ./ScanImageTiffReader image bytes '/v-data4/foconnell/data/parent/raw/MH70_0p6mm_FOV_50_550um_depth_som_stim_199mW_3min_M1_00001_00001.tif'
/v-data4/foconnell/repos/LBM-CaImAn-MATLAB/packages/scanimagetiffreader-matlab/external/ScanImageTiffReader-1.3-Linux/bin/ScanImageTiffReader 1.3-9c3423c by Vidrio Technologies <support@vidriotech.com>
34.735 GB
Elapsed: 1929.92ms

foconnell at v-gpu2 in /v-data4/foconnell/repos/LBM-CaImAn-MATLAB/packages/scanimagetiffreader-matlab/external/ScanImageTiffReader-1.3-Linux/bin (dev●)
$ ./ScanImageTiffReader image bytes '/v-data4/foconnell/data/test/hostpixelcorr_noavg_00001_00001.tif'
/v-data4/foconnell/repos/LBM-CaImAn-MATLAB/packages/scanimagetiffreader-matlab/external/ScanImageTiffReader-1.3-Linux/bin/ScanImageTiffReader 1.3-9c3423c by Vidrio Technologies <support@vidriotech.com>
1 MB
Elapsed: 0.932932ms
(base)
foconnell at v-gpu2 in /v-data4/foconnell/repos/LBM-CaImAn-MATLAB/packages/scanimagetiffreader-matlab/external/ScanImageTiffReader-1.3-Linux/bin (dev●)
$ ./ScanImageTiffReader image bytes '/v-data4/foconnell/data/parent/raw/MH70_0p6mm_FOV_50_550um_depth_som_stim_199mW_3min_M1_00001_00001.tif'
/v-data4/foconnell/repos/LBM-CaImAn-MATLAB/packages/scanimagetiffreader-matlab/external/ScanImageTiffReader-1.3-Linux/bin/ScanImageTiffReader 1.3-9c3423c by Vidrio Technologies <support@vidriotech.com>
34.735 GB
Elapsed: 1929.92ms
```

## System Information

```BASH
foconnell at v-gpu2 in /v-data4/foconnell/repos/LBM-CaImAn-MATLAB/packages/scanimagetiffreader-matlab/external/ScanImageTiffReader-1.3-Linux/bin (dev●)
$ lsblk

NAME                                MAJ:MIN RM   SIZE RO TYPE  MOUNTPOINTS
...
sda                                   8:0    0 953.9G  0 disk
└─sda1                                8:1    0 953.9G  0 part
  ├─ubuntu--vg-root                 253:2    0 930.4G  0 lvm   /var/snap/firefox/common/host-hunspell
  │                                                            /
  └─ubuntu--vg-swap_1               253:3    0   976M  0 lvm   [SWAP]
sdb                                   8:16   0 953.9G  0 disk
└─sdb1                                8:17   0 953.9G  0 part
  └─md0                               9:0    0   1.9T  0 raid0
    └─vg--ssd--raid0-lv--ssd--raid0 253:4    0   1.9T  0 lvm   /data1
sdc                                   8:32   0 953.9G  0 disk
└─sdc1                                8:33   0 953.9G  0 part
  └─md0                               9:0    0   1.9T  0 raid0
    └─vg--ssd--raid0-lv--ssd--raid0 253:4    0   1.9T  0 lvm   /data1
sr0                                  11:0    1  1024M  0 rom
nvme0n1                             259:0    0   3.6T  0 disk
└─nvme1--vg-data_nvme4tb            253:0    0   3.6T  0 lvm   /data2 #!! Raw data lives here
nvme1n1                             259:1    0 931.5G  0 disk
└─nvme0--vg-data_nvme               253:1    0 931.5G  0 lvm   /data0

```
