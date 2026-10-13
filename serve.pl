# perl serve.pl a 1234

use IO::Socket::INET;

my %types = (
    'css' => 'text/css',
    'html' => 'text/html',
    'ico' => 'image/x-icon',
    'js' => 'application/javascript'
);

sub serve {
    my ($folder, $port) = @_;
    $folder = 'a' if !$folder;
    $port = 1234 if !$port;
    my $index = '/x.html';
    if (substr($folder, -5) eq '.html') {
        if ((my $i = rindex($folder, '/')) != -1) {
            $index = substr($folder, $i);
            $folder = substr($folder, 0, $i);
        }
    }
    my $server = IO::Socket::INET->new(Listen => 5, LocalPort => $port, Reuse => 1);
    print("localhost:$port\n");
    while (1) {
        my $client = $server->accept();
        $client->recv(my $request, 4096);
        my @lines = split(' ', $request);
        if (scalar(@lines) == 1) {
            next;
        }
        my $file = $lines[1];
        if (substr($file, 0, 1) ne '/' or index($file, '..') != -1) {
            next;
        }
        $file =~ s/%20/ /g;
        my $type = substr($file, rindex($file, '.') + 1);
        if (exists($types{$type})) {
            $type = $types{$type};
        } else {
            $file = $index;
            $type = 'text/html';
        }
        if (open(my $f, '<', $folder . $file)) {
            local $/;
            my $content = <$f>;
            close($f);
            $client->send("HTTP/1.\ncontent-type:$type\n\n$content");
        }
        $client->close();
    }
}

serve($ARGV[0], $ARGV[1]);