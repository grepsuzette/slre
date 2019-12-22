package grepsuzette.slre;

/**
 * Option flags for a SLRE.
 * `i` case-insensitive matching, THIS IS THE DEFAULT contrarily to EReg.
 * `u` Unicode equivalence (e.g. "ç" is to match "c", same with "ě" and "e" etc.)
 *     THIS IS THE DEFAULT. But it is very much a work in progress as support
 *     will be added as new needs are met and not in a proactive way.
 * `I` case-sensitive, this is an upper-case i.
 * `U` no Unicode equivalence, this disables flag `u`.
 */
class Flags {
    public var unicodeEquiv     (default, null): Bool;
    public var caseSensitive    (default, null): Bool;

    @:throw public function new(flags:String="") {
        caseSensitive = false;
        unicodeEquiv     = true;
        //
        for (i in 0...flags.length) {
            switch flags.charAt(i) {
                case 'i': caseSensitive = false;   // default
                case 'I': caseSensitive = true;
                case 'u': unicodeEquiv  = true;
                case 'U': unicodeEquiv  = false;
                case xxx: throw "Unrecognized SLRE flag " + xxx;
            }
        }
    }
}


