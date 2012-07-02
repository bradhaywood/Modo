{
    package Modo;

    use warnings;
    use strict;
    
    our $VERSION = '0.001';
    $Modo::Classes = [];

    sub import {
        my ($class, %args) = @_;
        my $caller = caller;

        warnings->import();
        strict->import();

        localscope: {
            no strict 'refs';
    
            *{"${caller}::enum"} = sub {
                my ($name, @args) = @_;
                for (my $i = 0; $i < $#args; $i++) {
                    my $n = $i+1;
                    my $opt = $args[$i];
                    my @a = split(':', $opt);
                    if (@a > 1) {
                        $n   = $a[1];
                        $opt = $a[0];
                    }
                    *{"${name}::$opt"} = sub { return $n; };
                }
            };
                
            *{"${caller}::this"} = sub {
                return caller;
            };            

            *{"${caller}::say"} = sub {
                my $str = shift;
                if (! $str) {
                    warn "say() requires an argument";
                    return 0;
                }
                print "${str}\n";
            };

            *{"${caller}::private"} = sub {
                my ($name, $code) = @_;
            
                *{"${caller}::${name}"} = sub {
                    my $this = shift;
                    if (ref($this)) {
                        warn "${name} is a private method";
                        return;
                    }
                    $code->(@_);
                };
            };

            if ($args{as}) {
                if ($args{as} eq 'Class') {
                    *{ "$caller\::new" } = sub {
                        my ($self, %args) = @_;
                        my $a = { _used => {} };
                        if (%args) {
                            foreach my $arg (keys %args) {
                                $a->{$arg} = $args{$arg};
                                $a->{_used}->{$arg} = 1;
                            }
                        }
                        return bless $a, $caller;
                    };

                    *{ "$caller\::has" } = sub {
                        my ($name, %args) = @_;
                        $name = "${caller}::${name}";
                        my $rtype   = delete $args{is}||"";
                        my $default = delete $args{default}||"";
                        no strict 'refs';
                        if ($rtype eq 'ro') {
                            *{$name} = sub {
                                my ($self, $val) = @_;
                                if (@_ == 2) {
                                    warn "Cannot alter a Read-Only accessor";
                                    return ;
                                }
                                return $default;
                            };
                        }
                        else {
                            *{$name} = sub {
                                my ($self, $val) = @_;
                                if ($default && ! $self->{_used}->{$name}) {
                                    $self->{$name} = $default;
                                    $self->{_used}->{$name} = 1;
                                }
                                if (@_ == 2) {
                                    $self->{$name} = $val;
                                }
                                else {
                                    return $self->{$name}||"";
                                }
                            };
                        }
                    };

                    *{ "$caller\::extends" } = sub {
                        my (@classes) = @_;
                        my $pkg = $caller;

                        if ($pkg eq 'main') {
                            warn "Cannot extend main";
                            return ;
                        }

                        _extend_class( \@classes, $pkg );
                    };
                }
            }
        } # end localscope

        if ($args{is}) {
            _extend_class( $args{is}, $caller );
        }
    }
    
    sub _extend_class {
        my ($mothers, $class) = @_;

        foreach my $mother (@$mothers) {
            # if class is unknown to us, import it (FIXME)
            unless (grep { $_ eq $mother } @$Modo::Classes) {
                eval "use $mother";
                warn "Could not load $mother: $@"
                    if $@;
            
                $mother->import;
            }
            push @$Modo::Classes, $class;
        }

        {
            no strict 'refs';
            @{"${class}::ISA"} = @$mothers;
        }
    }

    sub what {
        my $self = shift;
        if (ref($self) eq 'Int') { return 'Int' }
        elsif (ref($self) eq 'Str') { return 'Str' }
        elsif (ref($self) eq 'Junction') { return 'Junction' }
    }

    sub val {
        my $self = shift;
        return $self->{_value};
    }

    sub say {
        my $self = shift;
        print $self->{_value} . "\n";
    }

    sub has {
        my ($self, $find) = @_;
        my $index = index($self->{_value}, $find);
        if ($index != -1) {
            return $index;
        }
        else { return 0; }
    }

    sub substr {
        my ($self, $off, $len, $rep) = @_;
        return substr($self->{_value}, $off, $len, $rep);
    }
}

{
    ## Str class
    package Str;
    
    use base 'Modo';
    
    sub new {
        my ($class, $str) = @_;
        
        my $self = {
            _value => $str||'',
        };
        
        return bless $self, 'Str';
    }

    sub concat {
        my ($self, $what) = @_;
        $what = $self->val
            if ref($what) eq 'Str';

        $self->{_value} .= $what;
        return $self;
    }

    sub first {
        my $self = shift;

        return substr($self->{_value}, 0, 1);
    }
}

{
    ## Int class
    package Int;
   
    use base 'Modo';
 
    sub new {
        my ($class, $int) = @_;
        
        my $self = {
            _value => $int||0,
        };

        return bless $self, 'Int';
    }

    sub add {
        my ($self, $int) = @_;
       
        $int = $int->val
            if ref($int) eq 'Int';
 
        $self->{_value} = $self->{_value} + $int;
        return $self;
    }

    sub subtract {
        my ($self, $int) = @_;

        $int = $int->val
            if ref($int) eq 'Int';

        $self->{_value} = $self->{_value} - $int;
        return $self;
    }

    sub divide {
        my ($self, $int) = @_;

        $int = $int->val
            if ref($int) eq 'Int';
    
        $self->{_value} = $self->{_value} / $int;
        return $self;
    }

    sub mult {
        my ($self, $int) = @_;

        $int = $int->val
            if ref($int) eq 'Int';
        
        $self->{_value} = $self->{_value} * $int;
        return $self;
    }
}

{
    ## Junctions :-D
    package Junction;
    
    use base 'Modo';
        
    sub new {
        my ($class, @j) = @_;
        
        if (! @j) {
            die "No list passed to junction\n";
        }

        my $self = {
            _list => \@j,
        };
        
        return bless $self, 'Junction';
    }

    sub loop {
        my ($self, $code) = @_;
        for (@{$self->{_list}}) { $code->($_); }
    }

    sub any {
        my ($self, $what) = @_;
        
        if (ref($what) eq 'Str') {
            $what = $what->val;
        }
        elsif (ref($what) eq 'Int') {
            $what = $what->val;
        }

        return grep { $_ eq $what } @{$self->{_list}};
    }
    
    sub first {
        my $self = shift;
        
        return $self->{_list}->[0];
    }
}

=head1 NAME

Modo - An attempt at a Modern Perl 5 implementation

=head1 DESCRIPTION

This module is my implementation of a Modern Perl 5. Your opinion may vary, but that's the beauty of Perl, it's whatever you make of it. Modo is a set of different classes to bring a modern feel to perl5 using data types. Now, I didn't want to use source filters or black magic to change the actual syntax of perl5, so it uses these classes to emulate Str, Int, etc.. objects. I've taken a type from perl6 (Junctions), because I just liked it. So there.
You can also turn Modo into a small class builder of sorts.

=head1 SYNOPSIS

    use Modo;

    # Basic Str example
    my $str = Str->new("Hello, World!");
    $str->say; # prints Hello, World!

    # What you can do with it after
    $str->concat("How")->concat("Are")->concat->("You?")->say;
    
    say $str->first; # get the first character
    say $str->substr(0, 1); # sure, or use substr

You can find more example below of what Modo can do.

=head1 DATA TYPES

=head2 Introduction

You don't need to use Modo data types - this is still perl5 after all. Do what you like. But if you want to use data types, they offer extra convenience methods to perform actions that might look a little ugly in standard Perl.
To obtain the raw value of any data type, just use C<val>,
At the time of writing, Modo is pretty bare. It doesn't validate the actual type just yet.

=head2 Int

    my $int = Int->new(5);
    say $int->val; # prints 5
        
    # chain methods to perform math
    say $int->add(5)->divide(2)->subtract(3)->mult(7);

=head2 Str

This was already demonstrated in the synopsis. Currently you can concatenate Str types, get the first character with ->first and perform substr.

=head2 Junction

This is a different beast alltogether. This implementation is fairly minimal, but here's an example anyway.

    my $day = 'Tuesday';
    my $weekdays = Junction->new(qw< Monday Tuesday Wednesday Thursday Friday >);
    
    if ($weekdays->any($day)) {
        say "OK, I'll see you on $day!";
    }

As you can see it just searches an array for the string passed to it. It does accept Str types too.

    my $day = Str->new('Wednesday');
    if ($weekdays->any($day)) { .. } # this will work

=head1 CLASSES AND METHODS

=head2 Turn Modo into a Class Builder

Turning Modo into a class builder is simple.

    package MyFoo;
    use Modo as => 'Class';
    
    1;

Above is a fully working class.. that doesn't do much, really. It injects the method 'new' for you, and also imports some class-only methods like C<has> and C<extends>.
Those familiar with modules like L<Moose> will know what I'm talking about.
C<has> creates a read-writable, or read-only accessor, and C<extends> will inherit another class.

    {
        package MyFoo;
        use Modo as => 'Class';
    
        has 'x' => ( is => 'rw', default => 5 );
    }

    my $foo = MyFoo->new;
    say $foo->x; # prints 5
    
    $foo->x(7); # updates x to 7
    say $foo->x; # prints 7

=head2 Methods

We can create "private" methods, which means that method cannot be called by anything outside of the class it lives in. For example,

    {
        package MyFoo;
    
        use Modo as => 'Class';
    
        private 'baz' => sub {
            say "Hello, World!";
        };
    }
    
    my $foo = MyFoo->new;
    $foo->baz; # throws a warning

However, if we create a method that calls it from within itself..

    sub callbaz {
        this->baz;
    }

then..
    
    $foo->callbaz; # prints Hello, World!

This seems to be OK because we called a public method that ran the private method for us. Oh, by the way, you can use C<this> to return the package name.

B<enum>

Let's take a look at the C<enum> method. I wanted something similar to perl6's enum, but done in perl5-style. With this we can create constants out of dynamically generated classes. Say we wanted to create our very own Boolean type.. yeah, we can do that.

    use Modo;

    enum Bool => ( 'True:1', 'False:0' );

    # set up a couple of test methods to test against our new Boolean type
    sub ok { return 1; }
    sub not_ok { return 0; }

    if (ok() == Bool->True) { say "We're good!"; }
    if (not_ok() == Bool->False) { say "This is false"; }

If you seperate an element with ':', then the value to the right will become the value of the method. If you omit this, then it will be the number of position in the list. For example, if we omited the 1 and 0 from our True and False elements, then True would have returned '1' and False would have returned '2'.

=cut

1;

