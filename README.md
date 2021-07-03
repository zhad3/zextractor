# zextractor

An utility tool to extract data from Gravity's GRF/GPF file formats as used by Ragnarok Online.

## Usage
`./zextractor -h`
```
A tool to extract files from one or multiple Gravity Resource Files (GRF)
-c     --configFile Specific config file to use instead of the default. Default: zextractor.conf
              --grf List of GRF filenames to load. Can contain multiple comma separated values. E.g. rdata.grf,data.grf. In that case rdata.grf would be loaded first. Default: 
   --keepLettercase Use original filenames. Whether the extracted files should have the same lower/uppercase as in the GRF. Default: false
   --printFiletable Creates a <grf filenames>_filetable.txt that contains the filetable information. Default: false
           --outdir Directory to place the extracted files into. Default: output
      --filtersfile Filename of the filters text file to use. Default: filters.txt
          --filters Comma separated filters. Default: 
          --extract Whether to extract any files. Default: true
-v        --verbose Verbose log/print statements. Default: false
-h           --help This help information.
```

## Examples
- **Extract all files of `data.grf`.**  
`./zextractor --grf=data.grf`
- **Extract all textures of `rdata.grf`.**  
`./zextractor --grf=rdata.grf --filters=data\\texture\\`
- **Extract all textures and all sprites of the merged GRF of `rdata.grf` and `data.grf`.**  
`./zextractor --grf=rdata.grf,data.grf --filters=data\\texture\\,data\\sprite\\`
- **Extract the single file `data/model/prontera/oven.rsm` from `data.grf`.**  
`./zextractor --grf=data.grf --filters=data\\model\\prontera\\oven.rsm`
- **Do not extract anything, but print the filetable of `data.grf` to `data.grf_filetable.txt`.**  
`./zextractor --grf=data.grf --extract=false --printFiletable`

If wanting to select multiple very specific files and or directories a filters file can be provided.
By default the program will look for an `filters.txt` file but can be changed via the `--filtersfile` option.
Inside the file each line will be treated as a filter in the same way as if it was provided through the `--filters` option with commas.

## Config
Most of the command line arguments are also available as a config file.
By default the program will try to read `zextractor.conf` in the same directory.
A custom config file can be specified by the command line argument `--configFile` or `-c` in short.

**Example config:**
```
[zextractor]
; List of GRF filenames to load. Can contain multiple comma separated values.
; E.g. rdata.grf,data.grf. In that case rdata.grf would be loaded first.
; Default value: 
;grf=

; Use original filenames. Whether the extracted files should have the same
; lower/uppercase as in the GRF.
; Default value: false
;keepLettercase=false

; Creates a <grf filenames>_filetable.txt that contains the filetable
; information.
; Default value: false
;printFiletable=false

; Directory to place the extracted files into.
; Default value: output
;outdir=output

; Filename of the filters text file to use.
; Default value: filters.txt
;filtersfile=filters.txt

; Comma separated filters.
; Default value: 
;filters=

; Whether to extract any files.
; Default value: true
;extract=true

; Verbose log/print statements.
; Default value: false
;verbose=false

```

## Building
Run `dub build` to build the program.

Run `dub run :configgenerator` to create the example config file.
