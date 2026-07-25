# perl bundle.pl a/a.js a/y.js

my $base64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789$_';

sub parse {
    my ($file, $imported) = @_;
    my $text;
    if (open($f, '<', $file)) {
        local $/;
        $text = <$f>;
        close($f);
    } else {
        $texts{$file} = '';
        return;
    }
    while ($text =~ / \n/) {
        $text =~ s/ \n/\n/g
    }
    while ($text =~ /\n\n/) {
        $text =~ s/\n\n/\n/g
    }
    my @lines = split("\n", $text);
    my $remove = 0;
    $text = '';
    for my $line (@lines) {
        if ($line =~ /^\s*\/\//) {
            next;
        }
        if (!$remove and index($line, '/*') > -1 and index($line, '//*') == -1) {
            if (index($line, '*/') > -1) {
                $line = substr($line, 0, index($line, '/*')) . ' ' . substr($line, index($line, '*/') + 2);
            } else {
                $line = substr($line, 0, index($line, '/*'));
                $remove = 1;
            }
        }
        if ($remove) {
            if (index($line, '*/') > -1) {
                $line = substr($line, index($line, '*/') + 2);
                $remove = 0;
            } else {
                next;
            }
        }
        $line =~ s/^\s+//;
        if ($line) {
            $text .= $line . "\n";
        }
    }
    my $texta = $text;

    sub resolve {
        my ($f, $file) = @_;
        if (substr($f, 0, 2) eq './') {
            $f = substr($f, 2);
        }
        if (substr($f, 0, 1) ne '.' and substr($f, 0, 1) ne '/') {
            my @split = split('/', $file);
            pop(@split);
            $f = join('/', @split) . '/' . $f;
        } elsif (index($f, '../') == 0) {
            my $i = 0;
            while (index($f, '../') == 0) {
                $f = substr($f, 3);
                $i++;
            }
            my @split = split('/', $file);
            splice(@split, -1 - $i);
            $i = join('/', @split);
            $f = length($i) ? $i . '/' . $f : $f;
        }
        return substr($f, -3) eq '.js' ? $f : $f . '.js';
    }

    my %files = ($file => ());
    my @order = ();
    my $i = index($text, 'import ');
    while ($i > -1) {
        if ($i != 0 and substr($text, $i - 1, 1) ne "\n" and substr($text, $i - 1, 1) ne ' ') {
            $text = substr($text, $i + 6);
            $i = index($text, 'import ');
            next;
        }
        $i += 6;
        while (substr($text, $i, 1) eq ' ') {
            $i++;
        }
        $text = substr($text, $i);
        $i = index($text, 'from');
        my $j = index($text, "'");
        my $k = index($text, '"');
        my @names = ();
        if ($i > -1 and ($i < $j or $j == -1) and ($i < $k or $k == -1)) {
            while ($i < length($text)) {
                $j = substr($text, $i - 1, 1);
                $k = substr($text, $i + 4, 1);
                if (($j eq ' ' or $j eq '}') and ($k eq ' ' or $k eq "'" or $k eq '"')) {
                    last;
                }
                $i += 4;
                $i += index(substr($text, $i), 'from');
            }
            @names = grep { $_ ne '' } split(/[ ,{}]/, substr($text, 0, $i));
            $i += 5;
            while (substr($text, $i, 1) eq ' ') {
                $i++;
            }
        } else {
            $i = 0;
        }
        my $f = substr($text, $i, 1);
        if ($f eq "'" or $f eq '"') {
            $text = substr($text, $i + 1);
            $f = resolve(substr($text, 0, index($text, $f)), $file);
            if (! exists($files{$f})) {
                $files{$f} = ();
                push(@order, $f);
            }
            push(@{$files{$f}}, @names);
        }
        $i = index($text, 'import ');
    }
    $modules{$file} = [@order];
    for my $i (@order) {
        if (! grep { $_ eq $i } @$imported) {
            if (! exists($modules{$i})) {
                return;
            } elsif (! grep { $_ eq $file } @{$modules{$i}}) {
                return;
            }
        }
    }
    my @exporta = ('async', 'class', 'const', 'default', 'function', 'let', 'var');
    my @repeata = ("\n", ' ', '(', ',', '.', '[');
    $text = $texta;
    $i = index($text, 'export ');
    while ($i > -1) {
        $text = substr($text, $i + 7);
        for my $name (@exporta) {
            $i = index($text, $name);
            if ($i > -1 and $i < 3) {
                $text = substr($text, $i + length($name));
            }
        }
        my $names = '';
        if (index($text, "\n") > -1) {
            $names = substr($text, 0, index($text, "\n"));
        }
        $i = 0;
        while (substr($names, $i, 1) eq ' ') {
            $i++;
        }
        my @split = ();
        if (substr($names, $i, 1) eq '{') {
            $names = substr($names, $i + 1);
            @split = split(',', substr($names, 0, index($names, '}')));
        } else {
            $i = index($names, '=');
            my $j = index($names, '(');
            if ($i == -1 or ($j > -1 and $i > $j)) {
                push(@split, $names);
            } else {
                while (index($names, '=') > -1) {
                    $i = index($names, '=');
                    push(@split, substr($names, 0, $i));
                    $names = substr($names, $i);
                    if (index($names, ',') > -1) {
                        $names = substr($names, index($names, ','));
                    } else {
                        last;
                    }
                }
            }
        }
        for my $name (@split) {
            while (grep { $_ eq substr($name, 0, 1) } @repeata) {
                $name = substr($name, 1);
            }
            for my $i (@repeata) {
                if (index($name, $i) > -1) {
                    $name = substr($name, 0, index($name, $i));
                }
            }
            push(@{$files{$file}}, $name);
        }
        $i = index($text, 'export ');
    }

    sub replace {
        my ($text, $past, $next) = @_;
        my $a = 0;
        my $i = length($past);
        my $j = length($next);
        while (index($text, $past, $a) > -1) {
            $a = index($text, $past, $a);
            if (length($text) < $a + $i + 1) {
                return $text;
            }
            my $cont = 0;
            my $textb = substr($text, $a - 7, 7) . $next;
            for my $name (@exporta) {
                if (index($textb, $name . '_') > -1) {
                    $cont = 1;
                    last;
                }
            }
            if ($cont or index($base64, substr($text, $a + $i, 1)) > -1
                or index($base64 . "'.", substr($text, $a - 1, 1)) > -1) {
                $a += $i;
                next;
            }
            $text = substr($text, 0, $a) . $next . substr($text, $a + $i);
            $a += $j;
        }
        return $text;
    }

    $text = $texta;
    for my $f (keys(%files)) {
        my $string = substr($f, 0, -3);
        $string =~ s/[^$base64]/_/g;
        for my $name (@{$files{$f}}) {
            $text = replace($text, $name, $name . '_' . $string);
        }
    }
    @lines = split("\n", $text);
    $text = '';
    for my $line (@lines) {
        my $a = $line;
        $a =~ s/^\s+//;
        if (index($a, 'export default ') == 0) {
            $line = substr($a, 15);
        } elsif (index($a, 'export ') == 0) {
            $line = substr($a, 7);
            $a = $line;
            $a =~ s/^\s+//;
            if (substr($a, 0, 1) eq '{') {
                next;
            }
        }
        if ($line and index($a, 'import ') != 0) {
            $text .= $line . "\n";
        }
    }
    $texts{$file} = $text;
}

sub build {
    my ($file, $output) = @_;
    my $file = 'a/a.js' if not defined $file;
    my $output = 'a/y.js' if not defined $output;
    my @imported = ();
    my @imports = ($file);
    our %modules = ();
    our %texts = ();
    while (@imports) {
        $file = $imports[0];
        if (grep { $_ eq $file } @imported) {
            @imports = grep { $_ ne $file } @imports;
        } else {
            parse($file, \@imported);
            unshift(@imports, @{$modules{$file}});
            if (exists($texts{$file})) {
                push(@imported, $file);
            }
        }
    }
    my $text = '';
    for my $file (@imported) {
        $text .= $texts{$file};
    }
    open($f, '>', $output);
    print $f $text;
    close($f);
}

build($ARGV[0], $ARGV[1]);