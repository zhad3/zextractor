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
        @Desc("Use original filenames. Whether the extracted files should have the same" ~
                " lower/uppercase as in the GRF.")
        bool keepLettercase = false;
        @Desc("Creates a <grf filenames>_filetable.txt that contains the filetable information.")
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
}

