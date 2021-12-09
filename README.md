# zextractor

An utility tool to extract data from Gravity's GRF/GPF file formats as used by Ragnarok Online as well as Aeomin's THOR patcher files.

## Usage
`./zextractor -h`
```
A tool to extract files from one or multiple Gravity Resource/Patch Files (GRF,GPF) or THOR files
-c     --configFile Specific config file to use instead of the default. Default: zextractor.conf
              --grf List of GRF filenames to load. Can contain multiple comma separated values. E.g. rdata.grf,data.grf. In that case rdata.grf would be loaded first. Default: 
             --thor THOR filename to load. Can only extract one THOR file at a time. Default: 
   --keepLettercase Use original filenames. Whether the extracted files should have the same lower/uppercase as in the GRF. Default: false
      --outputAscii Output ascii filenames. If set to true, the output filenames will use the raw ascii filenames instead of the converted korean utf encoding. Default: false
   --printFiletable Creates a <filenames>__filetable.txt that contains the filetable information. Default: false
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
`./zextractor --grf=rdata.grf --filters=data\\texture\\*`
- **Extract all textures and all sprites of the merged GRF of `rdata.grf` and `data.grf`.**  
`./zextractor --grf=rdata.grf,data.grf --filters=data\\texture\\*,data\\sprite\\*`
- **Extract the single file `data/model/prontera/oven.rsm` from `data.grf`.**  
`./zextractor --grf=data.grf --filters=data\\model\\prontera\\oven.rsm`
- **Do not extract anything, but print the filetable of `data.grf` to `data.grf__filetable.txt`.**  
`./zextractor --grf=data.grf --extract=false --printFiletable`
- **Extract all files of `my-patch.thor`.**  
`./zextractor --thor=my-patch.thor`

## Filters
If wanting to select multiple very specific files and or directories a filters file can be provided.
By default the program will look for an `filters.txt` file but can be changed via the `--filtersfile` option.
Inside the file each line will be treated as a filter in the same way as if it was provided through the `--filters` option with commas.

The filters support glob matching as defined here: https://dlang.org/phobos/std_path.html#globMatch

**Important note:** The filters cannot be in mojibake (e.g. æ–‡å—åŒ–ã‘) but should be properly UTF-8 encoded (e.g. 디제이맥스 테크니카 ).

## Config
Most of the command line arguments are also available as a config file.
By default the program will try to read `zextractor.conf` in the same directory.
A custom config file can be specified by the command line argument `--configFile` or `-c` in short.

See the [zextractor.example.conf](https://github.com/zhad3/zextractor/blob/main/zextractor.example.conf) file as an example.

## Docker
This tool is also available as a Container. Most likely you want to mount some input and some output directory. An example would be:
```
docker run --rm \
    -v <directory_with_grfs>:/zext/input \
    -v <output_directory>:/zext/output \
    -v my-filters.txt:/zext/filters.txt \
    zextractor --grf=input/data.grf
```
This command would extract any files from `data.grf` inside the `<directory_with_grfs>` folder that match the filters in the `my-filters.txt` file and write the output to the `<output_directory>` folder.

## Build Requirements
Please see the requirements of the [zgrf dependency](https://github.com/zhad3/zgrf#building)

## Building

Run `dub build` to build the program.

Run `dub run :configgenerator` to create the example config file.
