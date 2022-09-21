module config;

import zconfig : Section, Desc, Short, ConfigFile, Required;

struct Config
{
    @Section("zextractor")
    {
        @ConfigFile @Short("c") @Desc("Specific config file to use instead of the default.")
        string configFile = "zextractor.conf";
        @Desc("List of GRF filenames to load. Can contain multiple comma separated values. " ~
                "E.g. rdata.grf,data.grf. In that case rdata.grf would be loaded first.")
        string[] grf = [];
        @Desc("THOR filename to load. Can only extract one THOR file at a time.")
        string thor;
        @Desc("Use original filenames. Whether the extracted files should have the same" ~
                " lower/uppercase as in the GRF.")
        bool keepLettercase = false;
        @Desc("Output ascii filenames. If set to true, the output filenames will use the raw " ~
                "ascii filenames instead of the converted korean utf encoding.")
        bool outputAscii = false;
        @Desc("Creates a <filenames>__filetable.txt that contains the filetable information.")
        bool printFiletable = false;
        @Desc("Directory to place the extracted files into.")
        string outdir = "output";
        @Desc("Filename of the filters text file to use.")
        string filtersfile = "filters.txt";
        @Desc("Comma separated filters.")
        wstring[] filters = [];
        @Desc("Whether to extract any files.")
        bool extract = true;
        @Short("v") @Desc("Verbose log/print statements.")
        bool verbose = false;
    }
    @Section("patch-mode")
    {
        @Desc("Enable PatchMode. In PatchMode a separate filetable will be generated that keeps " ~
                "track of which GRF the extracted files belong to. This filetable will be consulted " ~
                "when extracting files from e.g. a patch file to make sure that no files are " ~
                "overwritten that belong to a GRF which is considered higher priority.")
        bool patchMode = false;
        @Desc("Write a patch filetable. If set to true it will create a patch filetable " ~
                "even if PatchMode is disabled. If PatchMode is enabled this setting is " ~
                "automatically set to true.")
        bool writePatchFiletable = false;
        @Desc("Priority list of GRF filenames for PatchMode. First entry has highest priority, " ~
                "followed by second and so on.")
        string[] patchPriority = [];
        @Desc("Use a specific filetable for PatchMode. If none is provided a default filetable " ~
                "called 'zextractor_filetable.dat' will be used in the 'outdir' directory.")
        string patchFiletable;
        @Desc("Target GRF of the input patch files. Specifying this will treat all files in the " ~
                "patch file as if they are supposed to be saved to the target GRF.")
        string patchTarget;
    }
}

