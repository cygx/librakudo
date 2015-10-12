unit sub MAIN(Str:D $nqpdir, *%reconfig);

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

my %defaults = WIN32
    ?? (rm         => 'rm-f.bat',
        shell      => 'cmd',
        shellflags => '/C')
    !! (rm         => 'rm -f',
        shell      => 'sh'.
        shellflags => '-c');

my %config = %($*VM.config), %defaults, %reconfig, :$nqpdir;

my &get-value = WIN32
    ?? -> $/ { %config{~$0}.?subst(:g, '\\', '/') // ~$/ }
    !! -> $/ { %config{~$0} // ~$/ }

my &fix-command = WIN32
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
