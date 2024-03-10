import config;
import logger;
import filetable;
import std.getopt;
import zconfig : initializeConfig, getConfigArguments;
import zgrf : VirtualGRF, GRF, GRFFile, GRFFiletable;
import zthor : THOR, THORFile, THORFiletable;

enum usage = "A tool to extract files from one or multiple Gravity Resource/Patch Files (GRF,GPF) or THOR files";

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

    if (config.grf.length == 0 && config.thor.length == 0)
    {
        log_fatal("No files to load.");
        return 1;
    }
    if (config.patchMode)
    {
        if (config.patchPriority.length == 0)
        {
            log_fatal("PatchMode enabled but no PatchPriority set");
            return 1;
        }
        if (config.patchTarget == string.init)
        {
            log_fatal("PatchMode enabled but no PatchTarget set");
            return 1;
        }
    }

    auto filters = parseFilters(config.filtersfile);

    // Add CLI/Config filters
    if (config.filters.length > 0)
    {
        filters ~= config.filters;
    }
    logf_info(filters.length > 0, "Loaded filters: %(%s, %)", filters);

    import std.exception : ErrnoException;
    import std.path : buildPath;

    Filetable patchFiletable;
    immutable(string) filetableFilename = config.patchMode && config.patchFiletable != string.init ? config.patchFiletable : buildPath(config.outdir, "zextractor_filetable.dat");

    if (config.patchMode)
    {
        import std.file : exists;
        if (exists(filetableFilename))
        {
            patchFiletable = loadFiletable(filetableFilename);
        }
        foreach (i, priority; config.patchPriority)
        {
            patchFiletable.priority[priority] = cast(int)(config.patchPriority.length - i);
        }
    }

    import zgrf.crypto.grfeditor : generateKey;
    import std.string : representation;
    ubyte[] grfEditorKey = config.grfEditorPassword !is null && config.grfEditorPassword.length >= 4
        ? generateKey(config.grfEditorPassword.representation)
        : [];

    if (config.grf.length > 1)
    {
        import zgrf : close;

        VirtualGRF grf;
        scope (exit)
            grf.close();
        try
        {
            grf = VirtualGRF(config.grf);

            if (grfEditorKey.length > 0)
            {
                import zgrf : setGRFEditorKey;
                grf.setGRFEditorKey(grfEditorKey);
            }
        }
        catch (ErrnoException e)
        {
            logf_fatal("Couldn't open GRF file. Message: %s", e.msg);
            return 1;
        }
        loadGRF!VirtualGRF(grf, config, filters);
        if (config.writePatchFiletable && !config.patchMode)
        {
            saveFiletable(grf.files, filetableFilename);
        }
        else if (config.patchMode)
        {
            addNewFiles(patchFiletable, grf.files, config.patchTarget);
            saveFiletable(patchFiletable, filetableFilename);
        }
        if (config.extract)
        {
            extractFiles!GRFFiletable(grf.files, config, patchFiletable);
        }
    }
    else if (config.grf.length == 1)
    {
        import zgrf : close;

        GRF grf;
        scope (exit)
            grf.close();
        try
        {
            grf = GRF(config.grf[0]);

            if (grfEditorKey.length > 0)
            {
                import zgrf : setGRFEditorKey;
                grf.setGRFEditorKey(grfEditorKey);
            }
        }
        catch (ErrnoException e)
        {
            logf_fatal("Couldn't open GRF file. Message: %s", e.msg);
            return 1;
        }
        loadGRF!GRF(grf, config, filters);
        if (config.writePatchFiletable && !config.patchMode)
        {
            saveFiletable(grf.files, filetableFilename);
        }
        else if (config.patchMode)
        {
            addNewFiles(patchFiletable, grf.files, config.patchTarget);
            saveFiletable(patchFiletable, filetableFilename);
        }
        if (config.extract)
        {
            extractFiles!GRFFiletable(grf.files, config, patchFiletable);
        }
    }

    if (config.thor.length > 0)
    {
        import zthor : close;

        THOR thor;
        scope (exit)
            thor.close();

        try
        {
            thor = THOR(config.thor);

            if (grfEditorKey.length > 0)
            {
                import zthor : setGRFEditorKey;
                thor.setGRFEditorKey(grfEditorKey);
            }
        }
        catch (Exception e)
        {
            logf_fatal("Couldn't open THOR file. Message: %s", e.msg);
            return 1;
        }
        loadTHOR(thor, config, filters);
        if (config.writePatchFiletable && !config.patchMode)
        {
            saveFiletable(thor.files, filetableFilename);
        }
        else if (config.patchMode)
        {
            addNewFiles(patchFiletable, thor.files, config.patchTarget);
            saveFiletable(patchFiletable, filetableFilename);
        }
        if (config.extract)
        {
            extractFiles!THORFiletable(thor.files, config, patchFiletable);
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
    import core.time : MonoTime;
    import zgrf : parse;

    log_info("Parsing GRFs and loading filetables...");
    auto startTime = MonoTime.currTime;

    grf.parse(filters);

    auto elapsed = MonoTime.currTime - startTime;
    logf_info("Finished loading filetables with a total of %d files after %s", grf.files.length, elapsed);

    if (conf.printFiletable)
    {
        import std.path : baseName;

        string filename;
        static if (is(T == VirtualGRF))
        {
            foreach (const ref g; grf.grfs)
            {
                filename ~= baseName(g.filename);
            }
        }
        else static if (is(T == GRF))
        {
            filename = baseName(grf.filename);
        }
        filename ~= "__filetable.txt";

        logf_info("Writing filetable to %s", filename);
        printGRFFiles(filename, grf.files);
    }

    return grf;
}

ref THOR loadTHOR(return ref THOR thor, const Config conf, const(wstring)[] filters)
{
    import core.time : MonoTime;
    import zthor : parse;

    log_info("Parsing THOR and loading filetable...");
    auto startTime = MonoTime.currTime;

    thor.parse(filters);

    auto elapsed = MonoTime.currTime - startTime;
    logf_info("Finished loading filetable with %d files after %s", thor.files.length, elapsed);

    if (conf.printFiletable)
    {
        import std.path : baseName;

        string filename = baseName(thor.filename) ~ "__filetable.txt";

        logf_info("Writing filetable to %s", filename);
        printTHORFiles(filename, thor.files);
    }
    return thor;
}

void extractFiles(T)(ref T files, const Config conf)
    if (is(T == GRFFiletable) || is(T == THORFiletable))
{
    extractFiles!T(files, conf, Filetable.init);
}

void extractFiles(T)(ref T files, const Config conf, const Filetable patchFiletable)
    if (is(T == GRFFiletable) || is(T == THORFiletable))
{
    import core.time : MonoTime;
    import std.file : exists, isDir, mkdirRecurse, FileException;
    import std.path : dirSeparator, dirName, buildPath;
    import zgrf : GRFFile;
    import zthor : THORFile;
    import std.zlib : ZlibException;

    log_info("Extracting files...");

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

    auto startTime = MonoTime.currTime;
    scope (exit)
    {
        auto elapsed = MonoTime.currTime - startTime;
        logf_info("Finished extracting after %s", elapsed);
    }

    ulong index = 1;

    foreach (ref file; files)
    {
        string filename;

        import std.utf : toUTF8;

        if (conf.outputAscii)
        {
            filename = convertRawNameToString(file.rawName).toUTF8;
        }
        else
        {
            filename = file.name.toUTF8;
        }

        if (conf.patchMode)
        {
            static if (is(T == GRFFiletable))
            {
                auto fileOrigin = conf.patchTarget == string.init ? file.grf.filename : conf.patchTarget;
            }
            else
            {
                auto fileOrigin = conf.patchTarget == string.init ? file.thor.header.grfTargetName : conf.patchTarget;
            }

            if (!equalOrHigherPriority(file.name, fileOrigin, patchFiletable))
            {
                if (conf.verbose)
                {
                    logf_info("[%d/%d] Low Priority: %s", index, files.length, filename);
                    index++;
                }
                continue;
            }
        }

        if (conf.verbose)
        {
            logf_info("[%d/%d] %s", index, files.length, filename);
            index++;
        }

        import std.path : baseName;

        version (Posix)
        {
            import std.array : replace;

            string fullpath = filename.replace("\\"w, "/"w);
            string path = dirName(fullpath);
        }
        else
        {
            string fullpath = filename;
            string path = dirName(fullpath);
        }

        string utf8path = buildPath(conf.outdir, path);
        string base = baseName(fullpath);

        if (!conf.keepLettercase)
        {
            import std.uni : toLower;

            utf8path = utf8path.asciiToLower;
            base = base.asciiToLower;
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

            static if (is(T == GRFFiletable))
            {
                import zgrf : getFileData;

                scope data = file.size == 0 ? [] : getFileData(*file.grf, file, No.useCache);
            }
            else static if (is(T == THORFiletable))
            {
                import zthor : FileFlags;

                scope ubyte[] data;

                if (!(file.flags & FileFlags.remove))
                {
                    import zthor : getFileData;

                    data = file.size == 0 ? [] : getFileData(*file.thor, file, No.useCache);
                }
                else if (conf.verbose)
                {
                    logf_info("%s has 'remove' flag. Nothing to extract.", file.name);
                }
            }

            auto f = File(buildPath(utf8path, base), "w+");
            if (data.length > 0)
            {
                f.rawWrite(data);
            }
            f.close();
        }
        catch (ErrnoException e)
        {
            logf_error("Couldn't create file \"%s\". Message: %s", base, e.msg);
        }
        catch (ZlibException e)
        {
            logf_error("Couldn't extract file \"%s\" due to a zlib error. Message: %s", filename, e.msg);
        }
        catch (Exception e) {
            logf_error("An error occurred extracting the file \"%s\". Message: %s", filename, e.msg);
        }
    }
}

wstring convertRawNameToString(const ubyte[] rawName) pure @safe
{
    import std.array : appender;

    auto app = appender!wstring;

    foreach (const b; rawName)
    {
        if (b == 0)
            break;

        app.put(cast(wchar) b);
    }

    return app.data;
}

string asciiToLower(inout string text) nothrow
{
    import std.ascii : toLower;

    char[] wasteOfMemory = text.dup;

    foreach (ref c; wasteOfMemory)
    {
        c = c.toLower;
    }
    return cast(immutable(char)[]) wasteOfMemory;
}

void printGRFFiles(const string filename, const ref GRFFiletable files)
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

void printTHORFiles(const string filename, const ref THORFiletable files)
{
    import std.stdio : File;

    auto f = File(filename, "w+");
    scope (exit)
        f.close();

    import zthor : THORFile;

    foreach (const ref file; files)
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
        app.formattedWrite("Filesize: %s bytes\n", file.size);
        app.formattedWrite("Filesize (compressed): %s bytes\n", file.compressed_size);
        app.formattedWrite("Flags: %d", file.flags);
        import zthor : FileFlags;

        if (file.flags == 0)
            app.put(" ADD");
        if (file.flags & FileFlags.remove)
            app.put(" REMOVE");
        app.put("\n");
        app.formattedWrite("Offset: %d\n", file.offset);
        app.formattedWrite("THOR: %s\n", file.thor.filename);

        f.write(app.data);
    }
}

