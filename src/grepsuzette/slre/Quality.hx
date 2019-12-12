package grepsuzette.slre;

import haxe.ds.Either;

// typedef QualityOrError = Either<Quality, QualityError>;

enum QualityError {
    PleaseInNCharacters(n:Int);     // e.g. when answering with 1 character instead 
    PleaseInNWords(n:Int);          // e.g. when answering with 1 character instead 
}

/**
 * Quality of match as returned by match_q(search).
 * Anything below 0 can not be used numerically.
 */
enum abstract Quality (Int) {
    var Perfect   = 10;
    var Good      = 8;  // Good can only be returned by 
                        // a custom filter passed to match_q().
                        // Good is an almost Perfect match.  
                        // When levenshtein distance is of 1, the match quality is just Average.
    var Average   = 5;  // almost all non perfect answers should give Bad or Average
    var Empty     = 2;  // whenever `search` is "".
    var Bad       = 0;  // Bad means non-Empty and sub-Average.
    
    public function toInt() : Int return this;

    @:op(A == B) public inline static function eq( a:Quality, b:Quality) : Bool return a.toInt() == b.toInt();
    @:op(A != B) public inline static function ne( a:Quality, b:Quality) : Bool return a.toInt() != b.toInt();
    @:op(A <= B) public inline static function le( a:Quality, b:Quality) : Bool return a.toInt() <= b.toInt();
    @:op(A >= B) public inline static function ge( a:Quality, b:Quality) : Bool return a.toInt() >= b.toInt();
    @:op(A <  B) public inline static function lt( a:Quality, b:Quality) : Bool return a.toInt() <  b.toInt();
    @:op(A >  B) public inline static function gt( a:Quality, b:Quality) : Bool return a.toInt() >  b.toInt();
}
