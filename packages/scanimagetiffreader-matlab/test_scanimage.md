# Testing ScanImageTiffReader Matlab Package

Error occurs on MATLAB versions: 2019a, 2022a, 2024a.

## Error

>> tfile = fullfile('/v-data4/foconnell/data/parent/raw/MH70_0p6mm_FOV_50_550um_depth_som_stim_199mW_3min_M1_00001_00001.tif')
>> isfile(tfile) % true, 1
>> reader=ScanImageTiffReader(tfile);
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

```bash
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

``` MATLAB
>> ver
----------------------------------------------------------------------------------------------------------------
MATLAB Version: 9.13.0.2126072 (R2022b) Update 3
MATLAB License Number: 41007384
Operating System: Linux 6.2.0-36-generic #37~22.04.1-Ubuntu SMP PREEMPT_DYNAMIC Mon Oct  9 15:34:04 UTC 2 x86_64
Java Version: Java 1.8.0_202-b08 with Oracle Corporation Java HotSpot(TM) 64-Bit Server VM mixed mode
----------------------------------------------------------------------------------------------------------------
MATLAB                                                Version 9.13        (R2022b)
Curve Fitting Toolbox                                 Version 3.8         (R2022b)
Deep Learning Toolbox                                 Version 14.5        (R2022b)
Global Optimization Toolbox                           Version 4.8         (R2022b)
Image Processing Toolbox                              Version 11.6        (R2022b)
MATLAB Compiler                                       Version 8.5         (R2022b)
Optimization Toolbox                                  Version 9.4         (R2022b)
Parallel Computing Toolbox                            Version 7.7         (R2022b)
Partial Differential Equation Toolbox                 Version 3.9         (R2022b)
Signal Processing Toolbox                             Version 9.1         (R2022b)
Statistics and Machine Learning Toolbox               Version 12.4        (R2022b)
Symbolic Math Toolbox                                 Version 9.2         (R2022b)
Wavelet Toolbox
```

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

$ lsb_release -a
No LSB modules are available.
Distributor ID: Ubuntu
Description:    Ubuntu 22.04.3 LTS
Release:        22.04
Codename:       jammy
```

## File Structure:

``` bash
I confirmed no path conflicts by removing older version of ScanImage (2016/2019).

flynn at pop-os in ~/repos/work/LBM-CaImAn-MATLAB (dev)
$ tree -L 5
.
├── packages/
│   └── scanimagetiffreader-matlab
│       ├── builddoc.m
│       ├── cmake
│       │   ├── git-versioning.cmake
│       │   ├── hide-symbols.cmake
│       │   ├── install-prefix.cmake
│       │   └── static-runtime.cmake
│       ├── CMakeLists.txt
│       ├── external
│       │   ├── CMakeLists.txt
│       │   ├── README.md
│       │   ├── ScanImageTiffReader-1.3-Darwin
│       │   │   ├── bin
│       │   │   ├── CMakeLists.txt
│       │   │   ├── include
│       │   │   └── lib
│       │   ├── ScanImageTiffReader-1.3-Linux
│       │   │   ├── bin
│       │   │   ├── CMakeLists.txt
│       │   │   ├── include
│       │   │   └── lib
│       │   └── ScanImageTiffReader-1.3-win64
│       │       ├── bin
│       │       ├── CMakeLists.txt
│       │       ├── include
│       │       └── lib
│       ├── hostpixelcorr_noavg_00001_00001.tif
│       ├── README.rst
│       ├── src
│       │   ├── build_mex
│       │   ├── CMakeCache.txt
│       │   ├── CMakeLists.txt
│       │   ├── Contents.m
│       │   ├── index.m
│       │   ├── mexScanImageTiffClose.c
│       │   ├── mexScanImageTiffClose.mexa64
│       │   ├── mexScanImageTiffData.c
│       │   ├── mexScanImageTiffData.mexa64
│       │   ├── mexScanImageTiffImageDescriptions.c
│       │   ├── mexScanImageTiffImageDescriptions.mexa64
│       │   ├── mexScanImageTiffMetadata.c
│       │   ├── mexScanImageTiffMetadata.mexa64
│       │   ├── mexScanImageTiffOpen.c
│       │   ├── mexScanImageTiffOpen.mexa64
│       │   ├── mexScanImageTiffReaderAPIVersion.c
│       │   ├── mexScanImageTiffReaderAPIVersion.mexa64
│       │   ├── ScanImageTiffReader.m
│       │   └── ScanImageTiffReaderTests.m
│       ├── test.bat
│       ├── test.m
│       └── test_scanimage.md

128 directories, 631 files
(base)

```

## MATLAB Path


