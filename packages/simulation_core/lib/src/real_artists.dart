import 'config/regions.dart';
import 'model.dart';

/// A real artist the AI field can use as a rival (docs K66): genre, home,
/// solo or group, the year they broke through and how big they became
/// (1 notable, 2 star, 3 superstar). The simulation decides how they do;
/// only the name, genre, home and starting craft come from here.
class RealArtist {
  const RealArtist(
      this.name, this.genre, this.home, this.kind, this.debut, this.star);
  final String name;
  final int genre;
  final HomeCountry home;
  final ArtistKind kind;
  final int debut;
  final int star;
}

/// Living artists only (no one who has died: their "new albums" would be
/// tasteless), and none with serious criminal convictions or charges.
/// One line each: name | genre | home | kind | breakthrough year | size.
const _data = '''
Madonna|pop|us|s|1983|3
U2|rock|eu|b|1980|3
Metallica|metal|us|b|1983|3
Iron Maiden|metal|uk|b|1980|2
Bob Dylan|folk|us|s|1962|2
Eric Clapton|blues|uk|s|1965|2
Buddy Guy|blues|us|s|1958|1
Bonnie Raitt|blues|us|s|1971|1
Yo-Yo Ma|classical|us|s|1978|1
Herbie Hancock|jazz|us|s|1962|1
Wynton Marsalis|jazz|us|s|1982|1
Earth, Wind & Fire|funk|us|b|1971|1
Kool & the Gang|funk|us|b|1969|1
Chic|disco|us|b|1977|1
Gloria Gaynor|disco|us|s|1975|1
UB40|reggae|uk|b|1980|1
Ziggy Marley|reggae|other|s|1985|1
George Strait|country|us|s|1981|2
Luis Miguel|latin|other|s|1982|2
Janet Jackson|pop|us|s|1982|2
Sarah Brightman|classical|uk|s|1985|1
Bad Religion|punk|us|b|1982|1
Red Hot Chili Peppers|rock|us|b|1984|2
Maná|latin|other|b|1987|2
Chayanne|latin|other|s|1987|1
CeCe Winans|gospel|us|s|1987|1
Yolanda Adams|gospel|us|s|1987|1
Goo Goo Dolls|rock|us|b|1987|1
Harry Connick Jr.|jazz|us|s|1987|1
Kylie Minogue|pop|other|s|1987|2
Garth Brooks|country|us|s|1989|3
Alan Jackson|country|us|s|1989|2
Lenny Kravitz|funk|us|s|1989|1
The Offspring|punk|us|b|1989|1
Mariah Carey|pop|us|s|1990|3
Celine Dion|pop|ca|s|1990|3
Green Day|punk|us|b|1990|3
Thalía|latin|other|s|1990|1
Twista|hiphop|us|s|1991|1
Brooks & Dunn|country|us|g|1991|1
Alejandro Sanz|latin|eu|s|1991|2
Ricky Martin|latin|other|s|1991|2
Fred Hammond|gospel|us|s|1991|1
Dr. Dre|hiphop|us|s|1992|2
Mary J. Blige|rnb|us|s|1992|2
TLC|rnb|us|g|1992|2
Moby|dance|us|s|1992|1
No Doubt|rock|us|b|1992|2
Martina McBride|country|us|s|1992|1
Paulina Rubio|latin|other|s|1992|1
Snoop Dogg|hiphop|us|s|1993|2
Shania Twain|country|ca|s|1993|3
Faith Hill|country|us|s|1993|2
Tim McGraw|country|us|s|1993|2
Toby Keith|country|us|s|1993|2
Radiohead|indie|uk|b|1993|2
Björk|indie|eu|s|1993|1
Jamiroquai|funk|uk|b|1993|2
Toni Braxton|rnb|us|s|1993|1
Marc Anthony|latin|us|s|1993|2
Carlos Vives|latin|other|s|1993|1
Kirk Franklin|gospel|us|s|1993|1
Diana Krall|jazz|ca|s|1993|1
Tool|metal|us|b|1993|1
Rancid|punk|us|b|1993|1
Shaggy|reggae|other|s|1993|2
The Roots|hiphop|us|b|1993|1
David Gray|folk|uk|s|1993|1
Sheryl Crow|rock|us|s|1993|1
Nas|hiphop|us|s|1994|2
OutKast|hiphop|us|g|1994|3
Usher|rnb|us|s|1994|3
Brandy|rnb|us|s|1994|1
Kenny Chesney|country|us|s|1994|2
Oasis|rock|uk|b|1994|2
Weezer|indie|us|b|1994|1
blink-182|punk|us|b|1994|2
Korn|metal|us|b|1994|1
Beck|indie|us|s|1994|2
Dave Matthews Band|rock|us|b|1994|1
Andrea Bocelli|classical|eu|s|1994|2
André Rieu|classical|eu|s|1994|1
Ben Harper|folk|us|s|1994|1
Beenie Man|reggae|other|s|1994|1
Keb' Mo'|blues|us|s|1994|1
Paul van Dyk|dance|eu|s|1994|1
Jimmy Eat World|punk|us|b|1994|1
Backstreet Boys|pop|us|g|1995|3
Alanis Morissette|rock|ca|s|1995|2
Foo Fighters|rock|us|b|1995|2
Shakira|pop|other|s|1995|3
Enrique Iglesias|pop|eu|s|1995|2
Daddy Yankee|latin|other|s|1995|2
Monica|rnb|us|s|1995|1
Rammstein|metal|eu|b|1995|2
Deftones|metal|us|b|1995|1
Incubus|rock|us|b|1995|1
D'Angelo|soul|us|s|1995|1
Susan Tedeschi|blues|us|s|1995|1
Femi Kuti|afro|other|s|1995|1
Staind|metal|us|b|1995|1
The Chemical Brothers|dance|uk|g|1995|1
*NSYNC|pop|us|g|1996|2
Jay-Z|hiphop|us|s|1996|3
Busta Rhymes|hiphop|us|s|1996|1
Nickelback|rock|ca|b|1996|2
Matchbox Twenty|rock|us|b|1996|1
Robbie Williams|pop|uk|s|1996|3
LeAnn Rimes|country|us|s|1996|1
Gary Allan|country|us|s|1996|1
Ginuwine|rnb|us|s|1996|1
Maxwell|soul|us|s|1996|1
Fatboy Slim|dance|uk|s|1996|1
Modest Mouse|indie|us|b|1996|1
Damian Marley|reggae|other|s|1996|1
Donnie McClurkin|gospel|us|s|1996|1
Ludovico Einaudi|classical|eu|s|1996|1
Missy Elliott|hiphop|us|s|1997|2
Daft Punk|dance|eu|g|1997|2
Tiësto|dance|eu|s|1997|2
Erykah Badu|soul|us|s|1997|1
Creed|rock|us|b|1997|1
Travis|indie|uk|b|1997|1
Sara Evans|country|us|s|1997|1
New Found Glory|punk|us|b|1997|1
Lil Jon|hiphop|us|s|1997|1
Destiny's Child|rnb|us|g|1998|3
Britney Spears|pop|us|s|1998|3
Lauryn Hill|soul|us|s|1998|2
Black Eyed Peas|hiphop|us|g|1998|2
The Chicks|country|us|g|1998|2
System of a Down|metal|us|b|1998|2
Death Cab for Cutie|indie|us|b|1998|1
Bright Eyes|indie|us|g|1998|1
Charlotte Church|classical|uk|s|1998|1
Timbaland|hiphop|us|s|1998|1
Cam'ron|hiphop|us|s|1998|1
Groove Armada|dance|uk|g|1998|1
Paul Oakenfold|dance|uk|s|1998|1
Eminem|hiphop|us|s|1999|3
Christina Aguilera|pop|us|s|1999|3
Jennifer Lopez|pop|us|s|1999|3
Lil Wayne|hiphop|us|s|1999|3
Slipknot|metal|us|b|1999|2
Muse|rock|uk|b|1999|2
The White Stripes|indie|us|g|1999|2
Westlife|pop|eu|g|1999|2
Dido|pop|uk|s|1999|2
Craig David|rnb|uk|s|1999|2
Keith Urban|country|other|s|1999|2
Brad Paisley|country|us|s|1999|1
Ja Rule|hiphop|us|s|1999|1
Mos Def|hiphop|us|s|1999|1
Jessica Simpson|pop|us|s|1999|1
Mandy Moore|pop|us|s|1999|1
S Club 7|pop|uk|g|1999|1
Ronan Keating|pop|eu|s|1999|1
Macy Gray|soul|us|s|1999|1
Basement Jaxx|dance|uk|g|1999|1
ATB|dance|eu|s|1999|1
Coldplay|rock|uk|b|2000|3
Linkin Park|rock|us|b|2000|3
Nelly|hiphop|us|s|2000|2
Ludacris|hiphop|us|s|2000|2
P!nk|pop|us|s|2000|2
Nelly Furtado|pop|ca|s|2000|2
Sia|pop|other|s|2000|2
Juanes|latin|other|s|2000|2
Rascal Flatts|country|us|g|2000|2
3 Doors Down|rock|us|b|2000|1
Disturbed|metal|us|b|2000|1
Good Charlotte|punk|us|b|2000|1
Jill Scott|soul|us|s|2000|1
Musiq Soulchild|rnb|us|s|2000|1
Mary Mary|gospel|us|g|2000|1
Sugababes|pop|uk|g|2000|1
Atomic Kitten|pop|uk|g|2000|1
Darude|dance|eu|s|2000|1
Doves|indie|uk|b|2000|1
Lang Lang|classical|other|s|2000|1
Sufjan Stevens|folk|us|s|2000|1
Joe Bonamassa|blues|us|s|2000|1
BoA|kpop|other|s|2000|1
Alicia Keys|rnb|us|s|2001|3
John Mayer|rock|us|s|2001|2
The Strokes|indie|us|b|2001|2
Josh Groban|classical|us|s|2001|2
Jack Johnson|folk|us|s|2001|2
T.I.|hiphop|us|s|2001|2
Fabolous|hiphop|us|s|2001|1
N.E.R.D|hiphop|us|g|2001|1
Michelle Branch|pop|us|s|2001|1
Sum 41|punk|ca|b|2001|1
Puddle of Mudd|rock|us|b|2001|1
India.Arie|soul|us|s|2001|1
The Shins|indie|us|b|2001|1
Avenged Sevenfold|metal|us|b|2001|1
Sophie Ellis-Bextor|disco|uk|s|2001|1
PSY|kpop|other|s|2001|1
Avril Lavigne|pop|ca|s|2002|2
Kelly Clarkson|pop|us|s|2002|2
Justin Timberlake|pop|us|s|2002|3
Ashanti|rnb|us|s|2002|2
Norah Jones|jazz|us|s|2002|2
Sean Paul|reggae|other|s|2002|2
David Guetta|dance|eu|s|2002|2
Vanessa Carlton|pop|us|s|2002|1
Girls Aloud|pop|uk|g|2002|1
Simple Plan|punk|ca|b|2002|1
Interpol|indie|us|b|2002|1
Audioslave|rock|us|b|2002|1
Mario|rnb|us|s|2002|1
Damien Rice|folk|eu|s|2002|1
Iron & Wine|folk|us|s|2002|1
Rain|kpop|other|s|2002|1
Benny Benassi|dance|eu|s|2002|1
Max Richter|classical|eu|s|2002|1
Wayne Wonder|reggae|other|s|2002|1
Beyoncé|rnb|us|s|2003|3
50 Cent|hiphop|us|s|2003|3
Evanescence|rock|us|b|2003|2
Kings of Leon|rock|us|b|2003|2
Michael Bublé|jazz|ca|s|2003|2
Fall Out Boy|punk|us|b|2003|2
Don Omar|latin|other|s|2003|2
Hilary Duff|pop|us|s|2003|1
Jamie Cullum|jazz|uk|s|2003|1
Joss Stone|soul|uk|s|2003|1
Yeah Yeah Yeahs|indie|us|g|2003|1
Anthony Hamilton|soul|us|s|2003|1
Clay Aiken|pop|us|s|2003|1
Chingy|hiphop|us|s|2003|1
P-Square|afro|other|g|2003|1
Kanye West|hiphop|us|s|2004|3
Maroon 5|pop|us|b|2004|2
The Killers|rock|us|b|2004|2
Ciara|rnb|us|s|2004|2
John Legend|soul|us|s|2004|2
Akon|rnb|us|s|2004|2
Pitbull|latin|us|s|2004|2
My Chemical Romance|punk|us|b|2004|2
Arcade Fire|indie|ca|b|2004|2
Franz Ferdinand|indie|uk|b|2004|1
Keane|rock|uk|b|2004|1
Snow Patrol|rock|eu|b|2004|1
Gretchen Wilson|country|us|s|2004|1
Scissor Sisters|disco|us|b|2004|1
Il Divo|classical|eu|g|2004|1
Ashlee Simpson|pop|us|s|2004|1
2Face Idibia|afro|other|s|2004|1
TVXQ|kpop|other|g|2004|1
Rihanna|pop|other|s|2005|3
Carrie Underwood|country|us|s|2005|3
T-Pain|rnb|us|s|2005|1
The Pussycat Dolls|pop|us|g|2005|1
James Blunt|pop|uk|s|2005|1
The Game|hiphop|us|s|2005|1
Young Jeezy|hiphop|us|s|2005|1
Trey Songz|rnb|us|s|2005|1
Sugarland|country|us|g|2005|1
Panic! at the Disco|punk|us|b|2005|1
Wisin & Yandel|latin|other|g|2005|1
Super Junior|kpop|other|g|2005|1
D'banj|afro|other|s|2005|1
Taylor Swift|country|us|s|2006|3
Ne-Yo|rnb|us|s|2006|2
Arctic Monkeys|indie|uk|b|2006|2
Fergie|pop|us|s|2006|2
BIGBANG|kpop|other|g|2006|2
Lily Allen|pop|uk|s|2006|1
Gnarls Barkley|soul|us|g|2006|1
Lupe Fiasco|hiphop|us|s|2006|1
Corinne Bailey Rae|soul|uk|s|2006|1
Hillsong United|gospel|other|g|2006|1
Miley Cyrus|pop|us|s|2007|3
Paramore|punk|us|b|2007|2
Leona Lewis|pop|uk|s|2007|2
OneRepublic|pop|us|b|2007|2
Calvin Harris|dance|uk|s|2007|2
Jonas Brothers|pop|us|g|2007|2
Girls' Generation|kpop|other|g|2007|2
Luke Bryan|country|us|s|2007|2
Soulja Boy|hiphop|us|s|2007|1
Mika|pop|uk|s|2007|1
Feist|indie|ca|s|2007|1
Jordin Sparks|pop|us|s|2007|1
Sara Bareilles|pop|us|s|2007|1
Wonder Girls|kpop|other|g|2007|1
Lady Gaga|pop|us|s|2008|3
Katy Perry|pop|us|s|2008|3
Adele|pop|uk|s|2008|3
Demi Lovato|pop|us|s|2008|2
Zac Brown Band|country|us|b|2008|2
Lady A|country|us|g|2008|2
Flo Rida|hiphop|us|s|2008|1
MGMT|indie|us|g|2008|1
Vampire Weekend|indie|us|b|2008|1
Duffy|soul|uk|s|2008|1
Fleet Foxes|folk|us|b|2008|1
Bon Iver|folk|us|b|2008|1
The Ting Tings|pop|uk|g|2008|1
Estelle|rnb|uk|s|2008|1
Drake|hiphop|ca|s|2009|3
Justin Bieber|pop|ca|s|2009|3
Kesha|pop|us|s|2009|2
Florence + the Machine|indie|uk|b|2009|2
Mumford & Sons|folk|uk|b|2009|2
Jason Derulo|pop|us|s|2009|2
Selena Gomez|pop|us|s|2009|2
Kid Cudi|hiphop|us|s|2009|1
Owl City|dance|us|s|2009|1
The xx|indie|uk|g|2009|1
2NE1|kpop|other|g|2009|1
La Roux|dance|uk|g|2009|1
Major Lazer|dance|us|g|2009|1
Nicki Minaj|hiphop|us|s|2010|3
Bruno Mars|pop|us|s|2010|3
Wiz Khalifa|hiphop|us|s|2010|2
Wizkid|afro|other|s|2010|2
Ellie Goulding|pop|uk|s|2010|2
Swedish House Mafia|dance|eu|g|2010|2
B.o.B|hiphop|us|s|2010|1
Miguel|rnb|us|s|2010|1
The Band Perry|country|us|g|2010|1
Tasha Cobbs Leonard|gospel|us|s|2010|1
Ed Sheeran|pop|uk|s|2011|3
The Weeknd|rnb|ca|s|2011|3
Kendrick Lamar|hiphop|us|s|2011|3
One Direction|pop|uk|g|2011|3
J. Cole|hiphop|us|s|2011|2
Lana Del Rey|indie|us|s|2011|2
Frank Ocean|rnb|us|s|2011|2
A\$AP Rocky|hiphop|us|s|2011|2
Davido|afro|other|s|2011|2
Skrillex|dance|us|s|2011|2
Foster the People|indie|us|b|2011|1
Alabama Shakes|blues|us|b|2011|1
Gotye|indie|other|s|2011|1
2Cellos|classical|eu|g|2011|1
Imagine Dragons|rock|us|b|2012|2
Macklemore & Ryan Lewis|hiphop|us|g|2012|2
Carly Rae Jepsen|pop|ca|s|2012|2
Burna Boy|afro|other|s|2012|2
EXO|kpop|other|g|2012|2
Little Mix|pop|uk|g|2012|2
Florida Georgia Line|country|us|g|2012|2
The Lumineers|folk|us|b|2012|2
fun.|pop|us|b|2012|1
Of Monsters and Men|folk|eu|b|2012|1
alt-J|indie|uk|b|2012|1
Mitski|indie|us|s|2012|1
Ariana Grande|pop|us|s|2013|3
BTS|kpop|other|g|2013|3
Lorde|pop|other|s|2013|2
Twenty One Pilots|rock|us|g|2013|2
Martin Garrix|dance|eu|s|2013|2
Kacey Musgraves|country|us|s|2013|2
J Balvin|latin|other|s|2013|2
HAIM|indie|us|g|2013|1
Chance the Rapper|hiphop|us|s|2013|1
Bastille|indie|uk|b|2013|1
Disclosure|dance|uk|g|2013|1
CHVRCHES|dance|uk|g|2013|1
Tiwa Savage|afro|other|s|2013|1
Sam Smith|pop|uk|s|2014|2
Hozier|soul|eu|s|2014|2
Meghan Trainor|pop|us|s|2014|2
Charli XCX|pop|uk|s|2014|2
Shawn Mendes|pop|ca|s|2014|2
5 Seconds of Summer|punk|other|b|2014|2
Kygo|dance|eu|s|2014|2
The Chainsmokers|dance|us|g|2014|2
Iggy Azalea|hiphop|other|s|2014|1
Tove Lo|pop|eu|s|2014|1
Sam Hunt|country|us|s|2014|1
Vance Joy|folk|other|s|2014|1
Glass Animals|indie|uk|b|2014|1
Travis Scott|hiphop|us|s|2015|2
Halsey|pop|us|s|2015|2
Sabrina Carpenter|pop|us|s|2015|2
Chris Stapleton|country|us|s|2015|2
TWICE|kpop|other|g|2015|2
Zara Larsson|pop|eu|s|2015|1
Lauren Daigle|gospel|us|s|2015|1
SEVENTEEN|kpop|other|g|2015|1
Alessia Cara|pop|ca|s|2015|1
Leon Bridges|soul|us|s|2015|1
Fetty Wap|hiphop|us|s|2015|1
Kehlani|rnb|us|s|2015|1
Post Malone|hiphop|us|s|2016|3
BLACKPINK|kpop|other|g|2016|3
Lil Uzi Vert|hiphop|us|s|2016|2
21 Savage|hiphop|us|s|2016|1
Anderson .Paak|soul|us|s|2016|1
Maren Morris|country|us|s|2016|1
Rag'n'Bone Man|soul|uk|s|2016|1
Dua Lipa|pop|uk|s|2017|3
Billie Eilish|pop|us|s|2017|3
Bad Bunny|latin|other|s|2017|3
SZA|rnb|us|s|2017|2
Khalid|rnb|us|s|2017|2
Cardi B|hiphop|us|s|2017|2
Camila Cabello|pop|us|s|2017|2
Luke Combs|country|us|s|2017|2
Daniel Caesar|rnb|ca|s|2017|1
Kane Brown|country|us|s|2017|1
H.E.R.|rnb|us|s|2017|1
Bebe Rexha|pop|us|s|2017|1
Ozuna|latin|other|s|2017|1
Rex Orange County|indie|uk|s|2017|1
Stray Kids|kpop|other|g|2018|2
Rosalía|latin|eu|s|2018|2
Lil Baby|hiphop|us|s|2018|2
Morgan Wallen|country|us|s|2018|2
Lauv|pop|us|s|2018|1
Maggie Rogers|indie|us|s|2018|1
Lizzo|pop|us|s|2019|2
Lewis Capaldi|pop|uk|s|2019|2
Doja Cat|pop|us|s|2019|2
Megan Thee Stallion|hiphop|us|s|2019|2
Lil Nas X|hiphop|us|s|2019|2
Rema|afro|other|s|2019|2
Clairo|indie|us|s|2019|1
Maverick City Music|gospel|us|g|2019|1
Roddy Ricch|hiphop|us|s|2019|1
Tones and I|pop|other|s|2019|1
Jack Harlow|hiphop|us|s|2020|2
The Kid LAROI|hiphop|other|s|2020|1
Tems|afro|other|s|2020|1
aespa|kpop|other|g|2020|1
Phoebe Bridgers|indie|us|s|2020|1
Conan Gray|pop|us|s|2020|1
Arlo Parks|indie|uk|s|2020|1
Olivia Rodrigo|pop|us|s|2021|3
Tate McRae|pop|ca|s|2021|2
Ayra Starr|afro|other|s|2021|1
IVE|kpop|other|g|2021|1
Måneskin|rock|eu|b|2021|1
Gracie Abrams|pop|us|s|2021|1
PinkPantheress|dance|uk|s|2021|1
NewJeans|kpop|other|g|2022|2
Zach Bryan|country|us|s|2022|2
LE SSERAFIM|kpop|other|g|2022|1
Asake|afro|other|s|2022|1
Steve Lacy|rnb|us|s|2022|1
Lainey Wilson|country|us|s|2022|1
Fred again..|dance|uk|s|2022|1
Peso Pluma|latin|other|s|2023|2
Noah Kahan|folk|us|s|2023|2
Benson Boone|pop|us|s|2023|2
Ice Spice|hiphop|us|s|2023|1
Tyla|afro|other|s|2023|1
Teddy Swims|soul|us|s|2023|1
Laufey|jazz|eu|s|2023|1
Chappell Roan|pop|us|s|2024|2
Shaboozey|country|us|s|2024|1
ILLIT|kpop|other|g|2024|1
BABYMONSTER|kpop|other|g|2024|1
''';

const _genres = {
  'pop': 0,
  'hiphop': 1,
  'rnb': 2,
  'rock': 3,
  'country': 4,
  'dance': 5,
  'latin': 6,
  'indie': 7,
  'metal': 8,
  'punk': 9,
  'soul': 10,
  'funk': 11,
  'disco': 12,
  'jazz': 13,
  'blues': 14,
  'folk': 15,
  'reggae': 16,
  'afro': 17,
  'kpop': 18,
  'gospel': 19,
  'classical': 20,
};

const _homes = {
  'us': HomeCountry.us,
  'ca': HomeCountry.canada,
  'uk': HomeCountry.uk,
  'eu': HomeCountry.europe,
  'other': HomeCountry.other,
};

const _kinds = {
  's': ArtistKind.solo,
  'b': ArtistKind.band,
  'g': ArtistKind.vocalGroup,
};

/// How big [name] became in real life (0 = not a real artist here).
int realStar(String name) => _stars[name] ?? 0;
final Map<String, int> _stars = {
  for (final a in realArtists) a.name: a.star,
};

/// Every real artist, in breakthrough-year order.
final List<RealArtist> realArtists = () {
  final out = <RealArtist>[];
  for (final line in _data.split('\n')) {
    if (line.trim().isEmpty) continue;
    final f = line.split('|');
    out.add(RealArtist(f[0], _genres[f[1]]!, _homes[f[2]]!, _kinds[f[3]]!,
        int.parse(f[4]), int.parse(f[5])));
  }
  out.sort((a, b) => a.debut.compareTo(b.debut));
  return List<RealArtist>.unmodifiable(out);
}();
