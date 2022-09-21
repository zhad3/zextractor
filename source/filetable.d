/**
 * # Filetable specification
 * ## Header
 * The header consists of the signature, version and number of entries. Encoding is little endian.
 *
 * ```
 * +-----------------------------------------------+
 * |                   Header                      |
 * |-----------------------------------------------|
 * | signature |      version     |   num entries  |
 * |  4 bytes  |      2 bytes     |     4 bytes    |
 * |  "zeft"   |---------|--------|                |
 * |           | minor   | major  |                |
 * |           | 1 byte  | 1 byte |                |
 * +-----------------------------------------------+
 * ```
 *
 * ## Data
 * After the header follows the data.
 *
 * ### Version 1.0 (0x100)
 * Repeat `num entries` (from the header) times the following data structure:
 *
 * ```
 * +-------------------------------------------------------------------+
 * |                               Entry                               |
 * |-------------------------------------------------------------------|
 * |              file               |              origin             |
 * |---------------------------------|---------------------------------|
 * | string len |    name (utf16)    | string len |    name (utf8)     |
 * |  2 bytes   | <string len> bytes |  1 byte    | <string len> bytes |
 * +-------------------------------------------------------------------+
 * ```
 */
module filetable;

import core.stdc.stdio : SEEK_SET, SEEK_END;
import std.system : Endian;
import std.stdio : File;
import std.exception : ErrnoException;
import std.bitmanip : nativeToLittleEndian, littleEndianToNative, read;
import std.string : representation;
import std.path : baseName;
import zgrf : GRFFiletable, GRFFile;
import zthor : THORFiletable, THORFile;
import logger;

enum signature = ['z', 'e', 'f', 't'];
enum ushort filetableVersion = 0x100;

struct FiletableHeader
{
    ushort _version;
    uint numEntries;
}

struct Filetable
{
    FiletableHeader header;
    string[wstring] entries;
    int[string] priority;
}


void saveFiletable(inout(GRFFiletable) filetable, const(string) targetFilename)
{
    auto file = File(targetFilename, "w+");
    writeHeader(file, cast(uint) filetable.length);

    foreach (ref const(GRFFile) entry; filetable.byValue)
    {
        immutable(ushort)[] nameData = entry.name.representation;
        immutable(ubyte)[] grfNameData = baseName(entry.grf.filename).representation;
        file.rawWrite(nativeToLittleEndian(cast(ushort)(2 * nameData.length)));
        file.rawWrite(nameData);
        file.rawWrite([cast(ubyte)(grfNameData.length)]);
        file.rawWrite(grfNameData);
    }
}

void saveFiletable(inout(THORFiletable) filetable, const(string) targetFilename)
{
    auto file = File(targetFilename, "w+");
    writeHeader(file, cast(uint) filetable.length);

    foreach (ref const(THORFile) entry; filetable.byValue)
    {
        auto nameData = entry.name.representation;
        auto thorNameData = baseName(entry.thor.filename).representation;
        file.rawWrite(nativeToLittleEndian(cast(ushort)(2 * nameData.length)));
        file.rawWrite(nameData);
        file.rawWrite([cast(ubyte)(thorNameData.length)]);
        file.rawWrite(thorNameData);
    }
}
void saveFiletable(inout(Filetable) filetable, const(string) targetFilename)
{
    auto file = File(targetFilename, "w+");
    writeHeader(file, cast(uint) filetable.entries.length);

    foreach (entry; filetable.entries.byKeyValue)
    {
        auto nameData = entry.key.representation;
        auto originNameData = entry.value.representation;
        file.rawWrite(nativeToLittleEndian(cast(ushort)(2 * nameData.length)));
        file.rawWrite(nameData);
        file.rawWrite([cast(ubyte)(originNameData.length)]);
        file.rawWrite(originNameData);
    }
}

Filetable loadFiletable(const(string) filename)
{
    Filetable filetable;
    try
    {
        auto file = File(filename, "r");
        filetable.header = readHeader(file);

        foreach (i; 0 .. filetable.header.numEntries)
        {
            import std.string : assumeUTF;
            auto temp = file.rawRead(new ubyte[2]);
            auto nameLen = temp.read!(ushort, Endian.littleEndian);
            temp = file.rawRead(new ubyte[nameLen]);
            wstring name = (cast(ushort[]) temp).assumeUTF;

            temp = file.rawRead(new ubyte[1]);
            temp = file.rawRead(new ubyte[temp[0]]);
            string targetName = temp.assumeUTF;

            filetable.entries[name] = targetName;
            //import std.utf : toUTF8;
            //log_info(name.toUTF8 ~ " : " ~ targetName);
        }
        return filetable;
    }
    catch (ErrnoException e)
    {
        // Fall through
        return Filetable.init;
    }
}

void addNewFiles(ref Filetable filetable, inout(GRFFiletable) grfFiletable, const(string) origin = string.init)
{
    foreach (const ref file; grfFiletable)
    {
        auto fileOrigin = origin == string.init ? file.grf.filename : origin;
        filetable.entries.require(file.name, baseName(origin));
    }
}

void addNewFiles(ref Filetable filetable, inout(THORFiletable) thorFiletable, const(string) origin = string.init)
{
    foreach (const ref file; thorFiletable)
    {
        auto fileOrigin = origin == string.init ? file.thor.header.grfTargetName : origin;
        filetable.entries.require(file.name, baseName(origin));
    }
}

bool equalOrHigherPriority(const(wstring) filename, const(string) origin, const(Filetable) filetable)
{
    import std.path : baseName;

    auto originPriority = baseName(origin) in filetable.priority;
    if (originPriority is null)
    {
        log_info("originPriority is null");
        return true;
    }

    auto filetableEntry = filename in filetable.entries;
    if (filetableEntry is null)
    {
        log_info("filetableEntry is null");
        return true;
    }

    auto filetableEntryPriority = *filetableEntry in filetable.priority;
    if (filetableEntryPriority is null)
    {
        log_info("filetableEntryPriority is null");
        return true;
    }

    return *originPriority >= *filetableEntryPriority;
}

private void writeHeader(File outFile, uint numEntries = 0)
{
    outFile.rawWrite(signature);
    outFile.rawWrite(nativeToLittleEndian(filetableVersion));
    outFile.rawWrite(nativeToLittleEndian(numEntries));
}

private FiletableHeader readHeader(File inFile)
{
    auto headerBuffer = inFile.rawRead(new ubyte[10]);
    if (headerBuffer[0 .. 4] != signature)
    {
        throw new Exception("Filetable header: Wrong signature");
    }
    headerBuffer.read!(uint);

    auto fileVersion = headerBuffer.read!(ushort, Endian.littleEndian);
    if (fileVersion > filetableVersion || fileVersion < 0x100)
    {
        throw new Exception("Filetable header: Unsupported version");
    }
    auto numEntries = headerBuffer.read!(uint, Endian.littleEndian);

    return FiletableHeader(fileVersion, numEntries);
}
