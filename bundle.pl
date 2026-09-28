# perl bundle.pl a/a.js a/y.js

my $base64 = '$0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz';

sub resolve {
    my ($f, $file) = @_;
    if (index($f, './') == 0) {
        $f = substr($f, 2);
    }
    my $i = substr($f, 0, 1);
    if ($i ne '.' and $i ne '/') {
        $f = substr($file, 0, rindex($file, '/')) . '/' . $f;
    } elsif (index($f, '../') == 0) {
        while (index($f, '../') == 0) {
            $f = substr($f, 3);
            $file = substr($file, 0, rindex($file, '/'));
        }
        $f = substr($file, 0, rindex($file, '/')) . '/' . $f;
    }
    if (substr($f, -3) ne '.js') {
        $f .= '.js';
    }
    return $f;
}

sub substitute {
    my ($next, $past, $text) = @_;
    my $a = 0;
    my $i = length($past);
    my $j = length($next);
    while (($a = index($text, $past, $a)) != -1) {
        if (index($base64, substr($text, $a + $i, 1)) != -1
            or ($a != 0 && index($base64 . "\"'.", substr($text, $a - 1, 1)) != -1)) {
            $a += $i;
            next;
        }
        $text = substr($text, 0, $a) . $next . substr($text, $a + $i);
        $a += $j;
    }
    return $text;
}

sub parse {
    my ($file, $modules, $texts) = @_;
    my $text;
    if (open(my $f, '<', $file)) {
        local $/;
        $text = <$f>;
        close($f);
    } else {
        $texts->{$file} = '';
        return;
    }
    my @lines = split("\n", $text);
    my $remove = 0;
    $text = '';
    for my $line (@lines) {
        if ($line =~ /^\s*\/\//) {
            next;
        }
        if (!$remove and (my $i = index($line, '/*')) != -1 and index($line, '//*') == -1) {
            if ((my $j = index($line, '*/')) != -1) {
                $line = substr($line, 0, $i) . ' ' . substr($line, $j + 2);
            } else {
                $line = substr($line, 0, $i);
                $remove = 1;
            }
        }
        if ($remove) {
            if ((my $i = index($line, '*/')) != -1) {
                $line = substr($line, $i + 2);
                $remove = 0;
            } else {
                next;
            }
        }
        $line =~ s/\s+$//;
        if ($line) {
            $text .= $line . "\n";
        }
    }
    my %files = ($file => []);
    my @order = ();
    my $texta = $text;
    while ((my $i = index($text, 'import ')) != -1) {
        if ($i != 0) {
            my $j = substr($text, $i - 1, 1);
            if ($j ne "\t" and $j ne "\n" and $j ne ' ') {
                $text = substr($text, $i + 6);
                next;
            }
        }
        $i += 6;
        while (substr($text, $i, 1) eq ' ') {
            $i++;
        }
        $text = substr($text, $i);
        $i = index($text, 'from');
        my $j = index($text, '"');
        my $k = index($text, "'");
        my @names = ();
        if ($i != -1 and ($i < $j or $j == -1) and ($i < $k or $k == -1)) {
            while ($i < length($text)) {
                $j = substr($text, $i - 1, 1);
                $k = substr($text, $i + 4, 1);
                if (($j eq ' ' or $j eq '}') and ($k eq ' ' or $k eq '"' or $k eq "'")) {
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
        if ($f eq '"' or $f eq "'") {
            $text = substr($text, $i + 1);
            $f = resolve(substr($text, 0, index($text, $f)), $file);
            if (!grep { $_ eq $f } @order) {
                $files{$f} = ();
                push(@order, $f);
            }
            push(@{$files{$f}}, @names);
        }
    }
    my @mods = ();
    for my $f (@order) {
        if (!exists($texts->{$f})) {
            push(@mods, $f);
            if (!exists($modules->{$f})) {
                $modules->{$file} = [@mods];
                return;
            }
        }
    }
    my @declares = ('async', 'class', 'const', 'default', 'function', 'let', 'var');
    my @defines = ("\n", ' ', '(', ',', '.', '[');
    $text = $texta;
    while ((my $i = index($text, 'export ')) != -1) {
        $text = substr($text, $i + 7);
        for my $name (@declares) {
            $i = index($text, $name);
            if ($i != -1 and $i < 3) {
                $text = substr($text, $i + length($name));
            }
        }
        my $names = '';
        if (($i = index($text, "\n")) != -1) {
            $names = substr($text, 0, $i);
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
            $i = index($names, '(');
            my $j = index($names, '=');
            if ($j == -1 or ($i < $j and $i != -1)) {
                push(@split, $names);
            } else {
                while ($j != -1 && substr($names, $j + 1, 1) ne '>') {
                    push(@split, substr($names, 0, $j));
                    $names = substr($names, $j);
                    if (($j = index($names, ',')) == -1) {
                        last;
                    }
                    $names = substr($names, $j);
                    $j = index($names, '=');
                }
            }
        }
        for my $name (@split) {
            while (grep { $_ eq substr($name, 0, 1) } @defines) {
                $name = substr($name, 1);
            }
            for $i (@defines) {
                if ((my $j = index($name, $i)) != -1) {
                    $name = substr($name, 0, $j);
                }
            }
            push(@{$files{$file}}, $name);
        }
    }
    $text = $texta;
    for my $f (keys(%files)) {
        my $path = substr($f, 0, -3);
        $path =~ s/[^$base64]/_/g;
        for my $name (@{$files{$f}}) {
            $text = substitute($name . '_' . $path, $name, $text);
        }
    }
    @lines = split("\n", $text);
    $text = '';
    for my $line (@lines) {
        my $a = $line;
        while ($a =~ /^\s+/) {
            $a = substr($a, length($&));
        }
        if (index($a, 'export default ') == 0) {
            $line = substr($a, 15);
        } elsif (index($a, 'export ') == 0) {
            $line = substr($a, 7);
            $a = $line;
            while ($a =~ /^\s+/) {
                $a = substr($a, length($&));
            }
            if (substr($a, 0, 1) eq '{') {
                next;
            }
        }
        if ($line and index($a, 'import ') != 0) {
            $text .= $line . "\n";
        }
    }
    $texts->{$file} = $text;
}

sub build {
    my ($file, $output) = @_;
    $file = 'a/a.js' if !$file;
    $output = 'a/y.js' if !$output;
    my @imported = ();
    my @imports = ($file);
    my %modules = ();
    my %texts = ();
    while (scalar(@imports) != 0) {
        $file = $imports[0];
        if (grep { $_ eq $file } @imported) {
            shift(@imports);
        } else {
            parse($file, \%modules, \%texts);
            if (exists($modules{$file})) {
                unshift(@imports, @{$modules{$file}});
            }
            if (exists($texts{$file})) {
                push(@imported, $file);
            }
        }
    }
    my $text = '';
    for $file (@imported) {
        $text .= $texts{$file};
    }
    open(my $f, '>', $output);
    print($f $text);
    close($f);
}

build($ARGV[0], $ARGV[1]);