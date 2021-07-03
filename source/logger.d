import core.vararg;
import std.conv : to;
import std.stdio : File, stdout;
import std.array : appender, Appender;

File logfile;
Appender!string msgAppender;

shared static this()
{
    logfile = stdout;
}

enum LogLevel
{
    Info,
    Warn,
    Error,
    Fatal,
    Debug
}

template logFunctions(LogLevel level)
{
    void log(A...)(lazy bool condition, lazy A args)
    {
        if (condition)
        {
            import std.format : formattedWrite;
            import std.conv : to;

            msgAppender = appender!string();
            msgAppender.put("[" ~ level.to!string ~ "] ");

            foreach (arg; args)
            {
                formattedWrite(msgAppender, "%s", arg);
            }

            logfile.writeln(msgAppender.data);
        }
    }

    void log(A...)(lazy A args)
    {
        import std.format : formattedWrite;
        import std.conv : to;

        msgAppender = appender!string();
        msgAppender.put("[" ~ level.to!string ~ "] ");

        foreach (arg; args)
        {
            formattedWrite(msgAppender, "%s", arg);
        }

        logfile.writeln(msgAppender.data);
    }

    void logf(A...)(lazy bool condition, lazy string msg, lazy A args)
    {
        if (condition)
        {
            import std.format : formattedWrite;
            import std.conv : to;

            msgAppender = appender!string();
            msgAppender.put("[" ~ level.to!string ~ "] ");

            formattedWrite(msgAppender, msg, args);

            logfile.writeln(msgAppender.data);
        }
    }

    void logf(A...)(lazy string msg, lazy A args)
    {
        import std.format : formattedWrite;
        import std.conv : to;

        msgAppender = appender!string();
        msgAppender.put("[" ~ level.to!string ~ "] ");

        formattedWrite(msgAppender, msg, args);

        logfile.writeln(msgAppender.data);
    }
}

alias log_info = logFunctions!(LogLevel.Info).log;
alias log_warn = logFunctions!(LogLevel.Warn).log;
alias log_error = logFunctions!(LogLevel.Error).log;
alias log_fatal = logFunctions!(LogLevel.Fatal).log;
alias log_debug = logFunctions!(LogLevel.Debug).log;

alias logf_info = logFunctions!(LogLevel.Info).logf;
alias logf_warn = logFunctions!(LogLevel.Warn).logf;
alias logf_error = logFunctions!(LogLevel.Error).logf;
alias logf_fatal = logFunctions!(LogLevel.Fatal).logf;
alias logf_debug = logFunctions!(LogLevel.Debug).logf;
