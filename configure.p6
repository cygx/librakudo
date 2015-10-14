use v6;
unit sub MAIN(
    Str:D :$nqpdir! is copy,
    Str:D :$rakudodir! is copy,
    *%reconfig);

constant GENSCRIPT = q:to/END-OF-SCRIPT/;
    sub expand-constant($/) {
        given ~$0 {
            when 'MOARDLL' { #`<moardllpath> }
            when 'NQPDLL' { #`<nqpdllpath> }
            when 'NQPDIR' { #`<nqpdir> }
            when 'RAKUDODIR' { #`<rakudodir> }
            default { ~$/ }
        }
    }

    sub expand-macro($/) {
        given ~$0 {
            when 'FILESIZE' {
                my $file = ~$1;
                (try $file.IO.s) // do {
                    note "PANIC: could not determine size of $file";
                    exit 1;
                }
            }
            default { ~$/ }
        }
    }

    print $*IN.slurp-rest
        . subst(:g, /__(\w+)__<![\(]>/, &expand-constant)
        . subst(:g, /__(\w+)__\((<-[\)]>+)\)/, &expand-macro);
    END-OF-SCRIPT

constant WIN32 = $*DISTRO.is-win;

if @*ARGS.grep(/\s/) {
    note 'SORRY: Arguments that contain whitespace break the build system...';
    exit 1;
}

$nqpdir    ~~ s/<[\\\/]>$//;
$rakudodir ~~ s/<[\\\/]>$//;

# do we need better shell detection?
my %defaults =
    perl6 => 'perl6',
    clang => 'clang',

    slip do given %reconfig<make> // $*VM.config<make> {
        when 'nmake'|'gmake' {
            shell => 'win32',
            rm    => 'build/rm-f.bat',
            mv    => 'move'
        }
        default {
            shell => 'posix',
            rm    => 'rm -f',
            mv    => 'mv'
        }
    }

my %config = %($*VM.config), %defaults, %reconfig,
    :$nqpdir, :$rakudodir, :libnqpconf(@*ARGS.join(' '));

%config<nqpdll>       //= sprintf %config<dll>, 'nqp';
%config<rakudodll>    //= sprintf %config<dll>, 'rakudo';
%config<nqpimplib>    //= sprintf %config<lib>, %config<nqpdll>;
%config<rakudoimplib> //= sprintf %config<lib>, %config<rakudodll>;
%config<moardllpath>  //= "{%config<libdir>}/{%config<moardll>}";
%config<nqpdllpath>   //= "{%config<libdir>}/{%config<nqpdll>}";

# normalize backslashes to forward slashes
my &get-value = WIN32
    ?? -> $/ { %config{~$0}.?subst(:g, '\\', '/') // ~$/ }
    !! -> $/ { %config{~$0} // ~$/ }

# undo slash normalization for commands when using nmake
my &fix-command = %config<make> eq 'nmake'
    ?? { .subst(:g, '/', '\\') }
    !! *.self;

spurt 'Makefile', slurp('build/Makefile.in')
    . subst(:g, /\<(\w+)\>/, &get-value)
    . subst(:g, /\t\S+/, &fix-command);

spurt 'gen.p6', GENSCRIPT.subst: :g, / '#`<' (\w+) '>' /, -> $/ {
    given $0 {
        when any <nqpdir rakudodir moardllpath nqpdllpath> {
            %config{$_}.subst(:g, '\\', '/').perl
        }
    }
}
