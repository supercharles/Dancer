package Dancer::App;

use strict;
use warnings;
use base 'Dancer::Object';

use Dancer::Config;
use Dancer::Route::Registry;

Dancer::App->attributes(qw(name prefix registry settings));

# singleton that saves any app created, we want unicity for app names
my $_apps = {};
sub applications { values %$_apps }

sub set_running_app {
    my ($self, $name) = @_;
    my $app = Dancer::App->get($name);
    $app = Dancer::App->new(name => $name) unless defined $app;
    Dancer::App->current($app);
}

sub find_route_through_apps {
    my ($class, $request) = @_;
    for my $app (Dancer::App->applications) {
        my $route = $app->find_route($request);
        return $route if $route;
    }
    return undef;
}

# instance

# FIXME should handle options
# FIXME should handle is_ajax
# FIXME should handle route cache
sub find_route {
    my ($self, $request) = @_;
    my $method = lc($request->method);
    my @routes = @{ $self->registry->routes($method) }; 

    for my $r (@routes) {
        my $match = $r->match($request);
        if ($match) {
            $r->match_data($match);
            return $r;
        }
    }
    return undef;
}

sub init {
    my ($self) = @_;
    $self->name('main') unless defined $self->name;

    die "an app named '".$self->name."' already exists" 
        if exists $_apps->{ $self->name };
    
    # default values for properties
    $self->settings({});
    $self->init_registry();

    $_apps->{ $self->name } = $self;
}

sub init_registry {
    my ($self, $reg) = @_;
    $self->registry($reg || Dancer::Route::Registry->new);
    if (Dancer::Config::setting('auto_page')) {
        Dancer::Route::Registry->universal_add('get', '/:page',
            sub {
                my $params = Dancer::SharedData->request->params;
                Dancer::Helpers::template($params->{'page'});
            }
        );
    }
}

# singleton that saves the current active Dancer::App object
my $_current;
sub current {
    my ($class, $app) = @_;
    return $_current = $app if defined $app;

    if (not defined $_current) {
        $_current = Dancer::App->get('main') || Dancer::App->new();
    }

    return $_current;
}

sub get {
    my ($class, $name) = @_;
    $_apps->{$name};
}

sub setting {
    my ($self, $name, $value) = @_;

    return (@_ == 3) 
        ? $self->settings->{$name} = $value
        : $self->settings->{$name};
}

1;