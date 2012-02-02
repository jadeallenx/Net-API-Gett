#!/usr/bin/perl

use strict;
use Test::More;
use File::Temp;

if (!eval { require Socket; Socket::inet_aton('open.ge.tt') }) {
    plan skip_all => "Cannot connect to the API server";
} 
elsif ( ! $ENV{GETT_API_KEY} || ! $ENV{GETT_EMAIL} || ! $ENV{GETT_PASSWORD} ) {
    plan skip_all => "API credentials required for these tests";
}
else {
    plan tests => 11;
}

# untaint environment variables
# They will be validated for correctness in the User.pm module, so just match anything here.

my @params = map {my ($v) = $ENV{uc "GETT_$_"} =~ /\A(.*)\z/; $_ => $v} qw(api_key email password);

use Net::API::Gett;

my $gett = Net::API::Gett->new( @params );

isa_ok($gett, 'Net::API::Gett', "Gett object constructed");
isa_ok($gett->request, 'Net::API::Gett::Request', "Gett request constructed");

isa_ok($gett->user, 'Net::API::Gett::User', "Gett User object constructed");
is($gett->user->has_access_token, '', "Has no access token");

$gett->user->login or die $!;

is($gett->user->has_access_token, 1, "Has access token now");

my $tmp = File::Temp->new();
open my $fh, ">", $tmp->filename;
print $fh <DATA>;
close $fh;

# Upload a file, download its contents, then destroy the share and the file
my $file = $gett->upload_file(
    filename => "queen_mab.txt",
    contents => $tmp->filename,
    title => "shakespeare",
    chunk_size => 1024,
);

isa_ok($file, 'Net::API::Gett::File', "File uploaded");

is($file->filename, "queen_mab.txt", "Got right filename");

my $content = $file->contents();

like($content, qr/Queen Mab/, "Got right file content");

my $share = $gett->get_share( $file->sharename );

is($share->title, "shakespeare", "Got right share title");

my $file1 = ($share->files)[0];

is($file1->size, -s $tmp->filename, "Got right filesize");

is($share->destroy(), 1, "Share destroyed");

__DATA__
SCENE IV. A street.

    Enter ROMEO, MERCUTIO, BENVOLIO, with five or six Maskers, Torch-bearers, and others 

ROMEO

    What, shall this speech be spoke for our excuse?
    Or shall we on without a apology?

BENVOLIO

    The date is out of such prolixity:
    We'll have no Cupid hoodwink'd with a scarf,
    Bearing a Tartar's painted bow of lath,
    Scaring the ladies like a crow-keeper;
    Nor no without-book prologue, faintly spoke
    After the prompter, for our entrance:
    But let them measure us by what they will;
    We'll measure them a measure, and be gone.

ROMEO

    Give me a torch: I am not for this ambling;
    Being but heavy, I will bear the light.

MERCUTIO

    Nay, gentle Romeo, we must have you dance.

ROMEO

    Not I, believe me: you have dancing shoes
    With nimble soles: I have a soul of lead
    So stakes me to the ground I cannot move.

MERCUTIO

    You are a lover; borrow Cupid's wings,
    And soar with them above a common bound.

ROMEO

    I am too sore enpierced with his shaft
    To soar with his light feathers, and so bound,
    I cannot bound a pitch above dull woe:
    Under love's heavy burden do I sink.

MERCUTIO

    And, to sink in it, should you burden love;
    Too great oppression for a tender thing.

ROMEO

    Is love a tender thing? it is too rough,
    Too rude, too boisterous, and it pricks like thorn.

MERCUTIO

    If love be rough with you, be rough with love;
    Prick love for pricking, and you beat love down.
    Give me a case to put my visage in:
    A visor for a visor! what care I
    What curious eye doth quote deformities?
    Here are the beetle brows shall blush for me.

BENVOLIO

    Come, knock and enter; and no sooner in,
    But every man betake him to his legs.

ROMEO

    A torch for me: let wantons light of heart
    Tickle the senseless rushes with their heels,
    For I am proverb'd with a grandsire phrase;
    I'll be a candle-holder, and look on.
    The game was ne'er so fair, and I am done.

MERCUTIO

    Tut, dun's the mouse, the constable's own word:
    If thou art dun, we'll draw thee from the mire
    Of this sir-reverence love, wherein thou stick'st
    Up to the ears. Come, we burn daylight, ho!

ROMEO

    Nay, that's not so.

MERCUTIO

    I mean, sir, in delay
    We waste our lights in vain, like lamps by day.
    Take our good meaning, for our judgment sits
    Five times in that ere once in our five wits.

ROMEO

    And we mean well in going to this mask;
    But 'tis no wit to go.

MERCUTIO

    Why, may one ask?

ROMEO

    I dream'd a dream to-night.

MERCUTIO

    And so did I.

ROMEO

    Well, what was yours?

MERCUTIO

    That dreamers often lie.

ROMEO

    In bed asleep, while they do dream things true.

MERCUTIO

    O, then, I see Queen Mab hath been with you.
    She is the fairies' midwife, and she comes
    In shape no bigger than an agate-stone
    On the fore-finger of an alderman,
    Drawn with a team of little atomies
    Athwart men's noses as they lie asleep;
    Her wagon-spokes made of long spiders' legs,
    The cover of the wings of grasshoppers,
    The traces of the smallest spider's web,
    The collars of the moonshine's watery beams,
    Her whip of cricket's bone, the lash of film,
    Her wagoner a small grey-coated gnat,
    Not so big as a round little worm
    Prick'd from the lazy finger of a maid;
    Her chariot is an empty hazel-nut
    Made by the joiner squirrel or old grub,
    Time out o' mind the fairies' coachmakers.
    And in this state she gallops night by night
    Through lovers' brains, and then they dream of love;
    O'er courtiers' knees, that dream on court'sies straight,
    O'er lawyers' fingers, who straight dream on fees,
    O'er ladies ' lips, who straight on kisses dream,
    Which oft the angry Mab with blisters plagues,
    Because their breaths with sweetmeats tainted are:
    Sometime she gallops o'er a courtier's nose,
    And then dreams he of smelling out a suit;
    And sometime comes she with a tithe-pig's tail
    Tickling a parson's nose as a' lies asleep,
    Then dreams, he of another benefice:
    Sometime she driveth o'er a soldier's neck,
    And then dreams he of cutting foreign throats,
    Of breaches, ambuscadoes, Spanish blades,
    Of healths five-fathom deep; and then anon
    Drums in his ear, at which he starts and wakes,
    And being thus frighted swears a prayer or two
    And sleeps again. This is that very Mab
    That plats the manes of horses in the night,
    And bakes the elflocks in foul sluttish hairs,
    Which once untangled, much misfortune bodes:
    This is the hag, when maids lie on their backs,
    That presses them and learns them first to bear,
    Making them women of good carriage:
    This is she--

ROMEO

    Peace, peace, Mercutio, peace!
    Thou talk'st of nothing.

MERCUTIO

    True, I talk of dreams,
    Which are the children of an idle brain,
    Begot of nothing but vain fantasy,
    Which is as thin of substance as the air
    And more inconstant than the wind, who wooes
    Even now the frozen bosom of the north,
    And, being anger'd, puffs away from thence,
    Turning his face to the dew-dropping south.

BENVOLIO

    This wind, you talk of, blows us from ourselves;
    Supper is done, and we shall come too late.

ROMEO

    I fear, too early: for my mind misgives
    Some consequence yet hanging in the stars
    Shall bitterly begin his fearful date
    With this night's revels and expire the term
    Of a despised life closed in my breast
    By some vile forfeit of untimely death.
    But He, that hath the steerage of my course,
    Direct my sail! On, lusty gentlemen.

BENVOLIO

    Strike, drum.

    Exeunt

