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
    my $server = IO::Socket::INET->new(
        Listen => 5,
        LocalPort => $port,
        Reuse => 1
    );
    print("localhost:$port\n");
    while (1) {
        my $client = $server->accept();
        $client->recv(my $request, 1024);
        my $file = (split(' ', $request))[1];
        $file =~ s/%20/ /g;
        my $type;
        if (substr($file, 0, 1) ne '/' or $file eq '/') {
            $file = '/x.html';
            $type = 'text/html';
        } else {
            $type = $types{($file =~ /\.([^.]+)$/)[0]};
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