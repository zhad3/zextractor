import std.getopt;
import logger;
import zgrf : VirtualGRF, GRF;
import config;
import zconfig : initializeConfig, getConfigArguments;

enum usage = "A tool to extract files from one or multiple Gravity Resource Files (GRF)";

int main(string[] args)
{
    string[] configArgs = getConfigArguments!Config("zextractor.conf", args);
    if (configArgs.length > 0)
    {
        import std.array : insertInPlace;

        args.insertInPlace(1, configArgs);
    }
    import std.getopt : GetOptException;

    Config config;
    bool helpWanted = false;
    try
    {
        config = initializeConfig!(Config, usage)(args, helpWanted);
    }
    catch (GetOptException e)
    {
        import std.stdio : stderr;

        stderr.writefln("Error parsing options: %s", e.msg);
        return 1;
    }

    if (helpWanted)
    {
        return 0;
    }

    if (config.grf.length == 0)
    {
        log_fatal("No GRFs to load.");
        return 1;
    }

    auto filters = parseFilters(config.filtersfile);

    // Add CLI/Config filters
    if (config.filters.length > 0)
    {
        filters ~= config.filters;
    }
    logf_info(filters.length > 0, "Loaded filters: %(%s, %)", filters);

    import std.exception : ErrnoException;

    if (config.grf.length > 1)
    {
        import zgrf : close;

        VirtualGRF grf;
        scope (exit)
            grf.close();
        try
        {
            grf = VirtualGRF(config.grf);
        }
        catch (ErrnoException e)
        {
            logf_fatal("Couldn't open GRF file. Message: %s", e.msg);
            return 1;
        }
        loadGRF!VirtualGRF(grf, config, filters);
        if (config.extract)
        {
            extractFiles(grf.files, config);
        }
    }
    else
    {
        import zgrf : close;

        GRF grf;
        scope (exit)
            grf.close();
        try
        {
            grf = GRF(config.grf[0]);
        }
        catch (ErrnoException e)
        {
            logf_fatal("Couldn't open GRF file. Message: %s", e.msg);
            return 1;
        }
        loadGRF!GRF(grf, config, filters);
        if (config.extract)
        {
            extractFiles(grf.files, config);
        }
    }

    return 0;
}

wstring[] parseFilters(const string filtersfile)
{
    import std.stdio : File;
    import std.exception : ErrnoException;

    wstring[] filters = [];

    if (filtersfile.length == 0)
    {
        return filters;
    }

    File f;

    try
    {
        f = File(filtersfile, "r");
    }
    catch (ErrnoException e)
    {
        logf_info("Couldn't read filters from file, continuing without. Message: %s", e.msg);
        return filters;
    }

    try
    {
        wstring line;
        while ((line = f.readln!wstring()) !is null)
        {
            import std.string : stripRight;

            if (line[0] == '#')
            {
                continue;
            }
            filters ~= line.stripRight();
        }
    }
    catch (Exception e)
    {
        logf_error("Couldn't read text from filters file, continuing with whatever"
                ~ " has been successfully read. Message: %s", e.msg);
    }

    return filters;
}

ref T loadGRF(T)(return ref T grf, const Config conf, const(wstring)[] filters)
        if (is(T == VirtualGRF) || is(T == GRF))
{
    import zgrf : parse;

    grf.parse(filters);

    if (conf.printFiletable)
    {
        string filename;
        static if (is(T == VirtualGRF))
        {
            foreach (const ref g; grf.grfs)
            {
                filename ~= g.filename;
            }
        }
        else static if (is(T == GRF))
        {
            filename = grf.filename;
        }
        filename ~= "_filetable.txt";

        logf_info("Writing filetable to %s", filename);
        printFiles(filename, grf.files);
    }

    return grf;
}

import zgrf : GRFFiletable;

void extractFiles(ref GRFFiletable files, const Config conf)
{
    import std.file : exists, isDir, mkdirRecurse, FileException;
    import std.path : dirSeparator, dirName, buildPath;
    import zgrf : GRFFile;

    if (!exists(conf.outdir))
    {
        try
        {
            mkdirRecurse(conf.outdir);
        }
        catch (FileException e)
        {
            logf_error("Couldn't create output directory \"%s\". Message: %s",
                    conf.outdir, e.msg);
            return;
        }
    }
    else if (!isDir(conf.outdir))
    {
        logf_error("Output directory \"%s\" is not a directory.", conf.outdir);
        return;
    }

    ulong index = 1;

    foreach (ref file; files)
    {
        if (conf.verbose)
        {
            logf_info("[%d/%d] %s", index, files.length, file.name);
            index++;
        }

        version (Posix)
        {
            import std.array : replace;

            wstring fullpath = file.name.replace("\\"w, "/"w);
            wstring path = dirName(fullpath);
        }
        else
        {
            wstring fullpath = file.name;
            wstring path = dirName(file.name);
        }
        import std.utf : toUTF8;
        import std.path : baseName;

        string utf8path = buildPath(conf.outdir, path.toUTF8);
        string base = baseName(fullpath).toUTF8;

        if (!conf.keepLettercase)
        {
            import std.uni : toLower;

            utf8path = utf8path.toLower;
            base = base.toLower;
        }

        try
        {
            mkdirRecurse(utf8path);
        }
        catch (FileException e)
        {
            logf_error("Couldn't create directory \"%s\" for file. Message: %s",
                    path, e.msg);
            return;
        }

        import std.exception : ErrnoException;

        try
        {
            import std.stdio : File;
            import std.typecons : No;
            import zgrf : getFileData;

            scope data = getFileData(*file.grf, file, No.useCache);

            auto f = File(buildPath(utf8path, base), "w+");
            f.rawWrite(data);
            f.close();
        }
        catch (ErrnoException e)
        {
            logf_error("Couldn't create file \"%s\". Message: %s", base, e.msg);
        }
    }
}

void printFiles(const string filename, const ref GRFFiletable files)
{
    import std.stdio : File;

    auto f = File(filename, "w+");
    scope (exit)
        f.close();

    import zgrf : GRFFile;

    foreach (const ref GRFFile file; files)
    {
        import std.array : appender;
        import std.format : formattedWrite;

        auto app = appender!wstring;

        app.put("============\n");
        app.put("Filename (ASCII): ");
        foreach (const b; file.rawName)
        {
            if (b == 0)
                break;

            app.put(cast(wchar) b);
        }
        app.put("\n");

        app.formattedWrite("Filename: %s\n", file.name);
        app.formattedWrite("Hash (CRC32): %X\n", file.hash);
        app.formattedWrite("Filesize: %s bytes\n", file.size);
        app.formattedWrite("Filesize (compressed): %s bytes\n", file.compressed_size);
        app.formattedWrite("Filesize (compressed, padded): %s bytes\n", file.compressed_size_padded);
        app.formattedWrite("Flags: %d", file.flags);
        import zgrf : FileFlags;

        if (file.flags & FileFlags.FILE)
            app.put(" FILE");
        if (file.flags & FileFlags.DES)
            app.put(" DES");
        if (file.flags & FileFlags.MIXCRYPT)
            app.put(" MIXCRYPT");
        app.put("\n");
        app.formattedWrite("Offset: %d\n", file.offset);
        app.formattedWrite("Offset (Filetable): %d\n", file.offset_ft);
        app.formattedWrite("GRF: %s\n", file.grf.filename);

        f.write(app.data);
    }
}
