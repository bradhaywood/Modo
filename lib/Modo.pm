## TODO:
# Make it so Data types don't have standard methods imported (like say, Conditional, etc)
{
    package Modo;

    use warnings;
    use strict;
   
    use parent 'autobox';
 
    our $VERSION = '0.001';
    $Modo::Classes = [];

    no warnings 'redefine';
    sub import {
        my ($class, %args) = @_;
        my $caller = caller;

        $class->SUPER::import(
            SCALAR => 'Str',
            ARRAY  => 'Array',
        );
        warnings->import();
        strict->import();
        localscope: {
            no strict 'refs';

            *{"${caller}::lambda"} = sub(&$) {
                my ($block, $ref) = @_;

                if (ref($ref) eq 'ARRAY') {
                    for (@{$ref}) {
                        $block->($_);
                    }
                }
                elsif (ref($ref) eq 'HASH') {
                    while(my ($key, $val) = each(%{$ref})) {
                        $block->($key, $val);
                    }
                }
            };

            *{"${caller}::enum"} = sub {
                my ($name, @args) = @_;
                for (my $i = 0; $i < @args; $i++) {
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

            *{"${caller}::prompt"} = sub {
                my ($text, $v) = @_;
                if ($v && $v == -1) {
                    print $text;
                }
                else { print "${text}\n"; }
                my $in = <STDIN>;
                chomp $in;
                return $in;
            };

            *{"${caller}::say"} = sub {
                my $str = shift;
                if (! defined $str) {
                    warn "say() requires an argument";
                    return 0;
                }
                if (ref($str) eq 'Int' or ref($str) eq 'Str') {
                    $str->say;
                }
                else {
                    print "${str}\n";
                }
            };

            *{"${caller}::conditional"} = sub {
                my ($name, @args) = @_;
                if ($name) {
                    my $pname = "Conditional::${name}";
                    *{$pname} = sub {
                        my $i;
                        my @err = ();
                        for (@args) {
                            $i++;
                            if ($_ =~ /^(\d+)/) {
                                push @err, $i
                                    if $1 == 0;
                            }
                        }

                        if (scalar(@err) > 0) {
                            return 0;
                        }
                        else {
                            return 1;
                        }
                    };
                }
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

                    *{ "$caller\::${caller}" } = sub(&;$) {
                        my $code = shift;
                        my $new = \&{"${caller}::new"};
                        *new = sub {
                            $code->(@_);
                            $new->(@_);
                        };

                        *{"${caller}::new"} = \*new;
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

    sub clone { bless { %{ $_[0] } }, ref $_[0] }

    sub WHAT {
        my $self = shift;
        if (ref($self) eq 'Int') { return 'Int' }
        elsif (ref($self) eq 'Str') { return 'Str' }
        elsif (ref($self) eq 'Array') { return 'Array' }
    }

    sub val {
        my $self = shift;
        return @{$self->{_value}}
            if ref($self) eq 'Array';
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

    sub size {
        my $self = shift;
        my $val = $self->{_value};
        return scalar(@{$val}) if $self->WHAT eq 'Array';
        return length($val) if $self->WHAT eq 'Str';
        return $val if $self->WHAT eq 'Int';
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
   
    use overload (
        '+' => sub {
            my $orig = shift;
                for (@_) {
                $orig->concat($_);
            }

            return $orig;
        },
        '/' => sub {
            my ($str, $delim) = @_;
            my @s = split($delim, $str->val);
            my $a = Array->new(@s);
            return $a;
        },
        '^' => sub {
            return uc shift->val;
        },
        fallback => 1
    );

    
    sub ob {
        return bless { _value => shift||'' }, 'Str';
    }
   
     sub new {
        my ($class, @str) = @_;
        return bless { _value => $str[0]||'' }, 'Str'
            if scalar(@str) == 1;
    
        my @a = ();
        for (@str) {
            push @a, Str->new($_);
        }
        return @a;
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
   
    use overload (
        '+' => sub {
            my $orig = shift;
            for(@_) {
                $orig->add($_);
            }
            return $orig;
        },
        '-' => sub {
            my $orig = shift;
            for(@_) {
                $orig->subtract($_);
            }
            return $orig;
        },
        '/' => sub {
            my $orig = shift;
            for(@_) {
                $orig->divide($_);
            }
            return $orig;
        },
        '*' => sub {
            my $orig = shift;
            for(@_) {
                $orig->mult($_);
            }
            return $orig;
        },
    );

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
    ## Array class
    package Array;
    
    use base 'Modo';
    
    use overload (
        '+' => sub {
            my $orig = shift;
            for my $arr (@_) {
                $orig->push(@{$arr});
            }
            return $orig;
        },
        '<<' => sub {
            my $orig = shift;
            for my $arr (@_) {
                $orig->insert(@{$arr});
            }
            return $orig;
        },
        '~~' => sub {
            my ($ob, $match) = @_;
            return $ob->any($match);
        },
        fallback => 1,
    );
    
    sub ob {
        return bless { _value => shift }, 'Array';
    }
        
    sub new {
        my ($class, @j) = @_;
        
        if (! @j) {
            die "No list passed to Array\n";
        }

        my $self = {
            _value => \@j,
        };
        
        return bless $self, 'Array';
    }
    
    sub as_ref {
        my $self = shift;
        return $self->{_value};
    }

    sub loop {
        my ($self, $code) = @_;
        for (@{$self->{_value}}) { $code->($_); }
    }

    sub push {
        my ($self, @list) = @_;
        push @{$self->{_value}}, @list;
        return $self;
    }

    sub insert {
        my ($self, @list) = @_;
        unshift @{$self->{_value}}, @list;
        return $self;
    }

    sub any {
        my ($self, $what) = @_;
        
        if (ref($what) eq 'Str') {
            $what = $what->val;
        }
        elsif (ref($what) eq 'Int') {
            $what = $what->val;
        }

        return grep { $_ eq $what } @{$self->{_value}};
    }
    
    sub first {
        my $self = shift;
        
        return $self->{_value}->[0];
    }

    sub last {
        my $self = shift;
        
        return $self->{_value}->[@{$self->{_value}}-1];
    }

    sub end {
        my $self = shift;
        return scalar(@{$self->{_value}}) - 1;
    }

    sub pairs {
        my $self = shift;
        my @pairs = ();
        if (scalar(@{$self->{_value}}) % 2 == 0) {
            while(my $key = shift @{$self->{_value}}) {
                push @pairs, { $key => shift @{$self->{_value}} }
            }
        }
        else {
            warn "Can't use pairs() on this Array. The count is not even";
            return $self;
        }
        
        return Array->new(@pairs);
    }

    sub get {
        my ($self, $index) = @_;
        return $self->{_value}->[$index];
    }

    sub sort {
        my $self = shift;
    
        my @s = sort { $a cmp $b } @{$self->{_value}};
        $self->{_value} = \@s;
        return $self;
    }
}

{
    ## Method class
    package Method;
   
    sub new {
        my ($class, $code) = @_;
        
        my $self = {
            _value => $code,
        };
        
        return bless $self, 'Method';
    }

    sub inject {
        my ($self, $name) = @_;
        my $caller = caller(1);
        *{"${caller}::${name}"} = $self->{_value};
    }

    sub push {
        my ($self, %args) = @_;
        
        my $class = $args{to}||undef;
        my $name  = $args{as}||undef;
        
        if ($class && $name) {
            *{"${class}::${name}"} = $self->{_value};
            return 1;
        }
        else {
            warn "Attributes 'as' and 'to' needed to push";
            return 0;
        }
    }

    sub run {
        my $self = shift;
        return $self->{_value}->(@_);
    }
}

=head1 NAME

Modo - An attempt at a Modern Perl 5 implementation

=head1 DESCRIPTION

This module is my implementation of a Modern Perl 5. Your opinion may vary, but that's the beauty of Perl, it's whatever you make of it. Modo is a set of different classes to bring a modern feel to perl5 using data types. Now, I didn't want to use source filters or black magic to change the actual syntax of perl5, so it uses these classes to emulate Str, Int, etc.. objects.
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

=head2 Array

Makes array operations a little more OO and prettier.

    my $day = 'Tuesday';
    my $weekdays = Array->new(qw< Monday Tuesday Wednesday Thursday Friday >);
    
    if ($weekdays->any($day)) {
        say "OK, I'll see you on $day!";
    }

As you can see it just searches an array for the string passed to it. It does accept Str types too.

    my $day = Str->new('Wednesday');
    if ($weekdays->any($day)) { .. } # this will work

C<push>

Use C<push> to push an element to the end of the array.

    say $arr->push('hello');

Like with most Modo things it returns an object, so we can do things like

    say $arr->push('foo')->size;

C<insert>

Inserts an element to the beginning of the array.

    say $arr->insert('baz');

C<end>

Returns the index of the last element

C<pairs>

Will only accept an even number of elements. It will pair them up, returning an Array with hashrefs of the results.

    my $arr = Array->new(qw<name Foo status Active>);
    $arr->pairs->loop(sub {
        foreach my $key (%$_) {
            say "$key: $_->{$key}";
        }
    });

    # returns
    # name: Foo
    # status: Active

=head2 Method

Yep, even methods can have their own class. Weird, right? While fairly useless, it can definitely be expanded on. Let's take a look at what you can do.

    my $method = Method->new(sub {
        my ($class, $name) = @_;
        $name = $class if !$name;
        say "Hello, ${name};
    });

Now, we can use C<inject> to add the new subroutine into the currect package. The only argument it takes is the name of the subroutine.

    $method->inject('foo');
    foo("World");
    __PACKAGE__->foo("World"); # prints Hello, World

Or, we can use C<push> to inject it into a different class.

    use FooClass;
    
    $method->push(
        to => 'FooClass',
        as => 'foo'
    );

    FooClass->foo("World"); # prints Hello, World

Using C<run> you can execute the subroutine, which it will then return the results. Arguments to C<run> are actually the arguments you want to pass to the subroutine.

    say $method->run("World", "Something else", "Foo");

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

B<lambda>

Not really a proper lambda, I guess. But I wasn't sure what else to name it. This works on arrayrefs or hashrefs, simply pass it a block, then the ref and it will iterate through it while passing the value, or key and value if applicable as arguments.

    # print 1 to 5
    lambda {
        say $_[0];
    } [ 1..5 ];

    # or you can do hashrefs
    my $h = {
        name  => 'Foo',
        age   => 5,
        place => 'Perl Land'
    };

    lambda {
        my ($key, $val) = @_;
        say "Key: $key";
        say "Value: $val";
    } $h;

B<clone>

C<clone> can be performed on most data type classes (ie: Array, Str and Int). It creates a copy of the instance so you can perform actions without mutating the original object.

    my $str = Str->new("Hello");
    say $str->clone->concat(", World");
    say $str;

    # outputs:
    # Hello, World
    # Hello

C<prompt>

Takes user input and returns it. This will also chomp the newline from the end for you. It takes two arguments, the last one being optional. The first argument is a line of text to present to the user before the STDIN is taken, the second, if you pass a -1 it will not add a newline to the end of the string sent.

    my $name = prompt("Please enter your name: ", -1);
    say "Hello, ${name}!";

    my $stuff = prompt("Type stuff below");
    say "You said: ${stuff}";

C<size>

This is another data type method you can use on Strings, Integers and Arrays. For strings, it will return the length of the string. With Arrays it will return the number of elements, and it just returns the integer as itself. Useless, right?

    my $arr = Array->new(qw< a b c d e >);
    say $arr->size;

C<WHAT>

Call this on any data type method to get its type. For example,

    my $this = Str->new("Hey");
    my $that = Array->new(1..6);
    
    say $this->WHAT; # Str
    say $that->WHAT; # Array

=head1 ATTRIBUTES

You can now access data types using attributes. If, for some reason, you didn't want to create a normal variable, like

    my $x = Int->new(5);

You can now do it as such,

    sub x :Int { 5 }

The above will create a subroutine called 'x' with the value of 5 as an Int type. So you can do this stuff,

    sub i :Int { 5 }
    say i->add(5); # outputs 10

This works with Str and Array too, of course

    sub str :Str { 'Hello' }
    say str->concat(', World!'); # prints Hello, World!
    
    sub myarr :Array { 1..10 }
    myarr->loop(sub { say $_ }); # prints 1 to 10 

=head1 CONDITIONALS

A new type of class in Modo is C<Conditionals>. Basically, instead of writing an C<if> statement with a large number of tests, you can convert them all into one conditional and test that. As it creates a class per-conditional you can share them anywhere and resume them.

    # The conditional below would fail
    # because one of the tests equals 0
    conditional 'MyCond' => (
        this_method(),
        that_method(),
        10-10,
    );

    if (Conditional->MyCond) {
        say "We're good :-)";
    }
    else {
        say "There was a problem";
    }

When you call C<Conditional>, it will run through every test, and if any are false (equal to 0), then it returns 0 itself. If they all pass, it will return 1 for true.

=head1 OVERLOADED OPERATORS

These beautiful things allow us to perform some chained methods by using standard operators. For example, to C<push> a new list to an existing Array data class, we can use C<+>.

    my $arr = Array->new(1..2); # setup the default Array
    my @b = qw(Hello there);
    my @c = qw(World);    

    ($arr + \@b + \@c)->loop(sub {
        say $_;
    });

The above example adds the two arrays @b and @c to the default Array object, then iterators through it. Yes, we totally just did that.
We can also tell the Array we want to C<insert> elements to the front of the array like so

    $arr << \@b << \@a

It also works for Ints and Strs. Why have I chosen to overload strings? Because strings shouldn't be allowed to perform math.

    my $str = Str->new("Hello");
    say $str + " World";

That will call C<concat> on the string and mangle it for you, without actually calling concat.

We can split strings quite easily with '/'

    my $str = Str->new('Hello:there:world');
    ($str / ':')->loop(sub {
        say $_;
    });
    
As you can see, it returns an Array class for you instead of a standard array.

=cut

1;

