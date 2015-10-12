use v6;
unit sub MAIN(Str:D $nqpdir is copy, *%reconfig);

constant GENSCRIPT = q:to/END-OF-SCRIPT/;
    print $*IN.slurp-rest.subst: :g, /__(\w+)__[\((<-[\)]>+)\)]?/, -> $/ {
        given $0 {
            when 'MOARDLL' { #`<dllpath> }
            when 'PATH' { #`<nqpdir> ~ "/$1" }
            when 'FILESIZE' {
                my $file = #`<nqpdir> ~ "/$1";
                (try $file.IO.s) // do {
                    note "PANIC: could not determine size of $file";
                    exit 1;
                }
            }
            default { ~$/ }
        }
    }
    END-OF-SCRIPT

constant WIN32 = $*DISTRO.is-win;

if @*ARGS.grep(/\s/) {
    note 'SORRY: Arguments that contain whitespace break the build system...';
    exit 1;
}

$nqpdir ~~ s/<[\\\/]>$//;

# do we need better shell detection?
my %defaults = do given %reconfig<make> // $*VM.config<make> {
    when 'nmake'|'gmake' {
        shell => 'win32',
        rm    => 'rm-f.bat',
        mv    => 'move'
    }
    default {
        shell => 'posix',
        rm    => 'rm -f',
        mv    => 'mv'
    }
}

my %config = %($*VM.config), %defaults, %reconfig,
    :$nqpdir, :libnqpconf(@*ARGS.join(' '));

# normalize backslashes to forward slashes
my &get-value = WIN32
    ?? -> $/ { %config{~$0}.?subst(:g, '\\', '/') // ~$/ }
    !! -> $/ { %config{~$0} // ~$/ }

# undo slash normalization for commands when using nmake
my &fix-command = %config<make> eq 'nmake'
    ?? { .subst(:g, '/', '\\') }
    !! *.self;

spurt 'Makefile', slurp('Makefile.in')
    . subst(:g, /\<(\w+)\>/, &get-value)
    . subst(:g, /\t\S+/, &fix-command);

spurt 'gen.p6', GENSCRIPT.subst: :g, / '#`<' (\w+) '>' /, -> $/ {
    given $0 {
        when 'nqpdir' {
            $nqpdir.subst(:g, '\\', '/').perl
        }
        when 'dllpath' {
            "{%config<libdir>}/{%config<moardll>}".subst(:g, '\\', '/').perl
        }
    }
}
