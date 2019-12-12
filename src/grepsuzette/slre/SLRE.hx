package grepsuzette.slre;

import haxe.ds.Either;
import grepsuzette.slre.Flags;
import grepsuzette.slre.Quality;
using StringTools;

/**
 * Simple Linguistic Regular Expressions.
 * They have little to do with things commonly called "regex" in computing, 
 * being much more simple to write for casual users, while being also more
 * expressive or at least more useful to enter simple and short linguistic
 * patterns than wildcard expressions. 
 *
 * Examples:
 * 1. `dark|black|shadowed|sunless`: Implicit alternation, using `|`.
 * 2. `{dark|black} {chocolate|cocoa}`: Delimiting alternation, using `{}`. This means "black chocolate" or "dark cocoa" for instance are matches.
 * 3. `colo[u]r`, `a [very|quite|somewhat] hot summer`: Optional markup, using `[]`. 
 * 4. `some part[ completely {optional|up to you}] that you will write yourself`: Nesting.
 * 5. `[Yesterday |Monday ]{[s]he|it} {negligently} drove a {[Mercedes[-| ] ]Benz|Ferrari|Porsche}: Same as 4, longer (probably too long) example.
 */
class SLRE {

    /**
     * maximum level of nested []{}. Nestedness foolsafe...
     * This is configurable and you don't want to set it too high for now
     * (because match() uses _expand() for the time being, which develops 
     * all possible expressions). TODO to change this, match() would need
     * to itself exploit the parsed tree. Besides nestedness is of course 
     * not all that matters, but also the number of alternations.
     *
     * Used only for creating new SLRE when third argument is unspecified.
     */
    public static var DEFAULTMAXDEPTH : Int = 6;          

    public var pattern (default, null) : String;
    public var flags   (default, null) : Flags;
    public var maxdepth(default, null) : Int;

    var _ast      : NodeSeq;        // cached parsed tree, note the pattern parsed only when needed (lazy)
    var _expanded : Array<String>;  // cached expanded. Not sure if we will keep it. (lazy too)

    /**
     * Ctor.
     * @param (String pattern) such as "{blue|green|black} is my favourite colo[u]r [on earth]."
     * @param (String flags) 
     * @param (maxdepth) <= 0 here will automatically use the DEFAULTMAXDEPTH value.
     */
    public function new(pattern:String, flags:String="", maxdepth=0) {
        this.pattern  = pattern;
        this.flags    = new Flags(flags);
        this.maxdepth = maxdepth <= 0 ? DEFAULTMAXDEPTH : maxdepth;
    }

    /**
     * Static style create(), e.g. when you need to chain stuffs.
     * See new() for arguments.
     */
    public inline static function create(pattern:String, flags:String="", maxdepth=0) : SLRE
        return new SLRE(pattern, flags, maxdepth);


    /**
     * Strict match.
     * This can be seriously optimized in that
     * right now we just _expand() the parse tree
     * to all matching strings (modulo the letter's case of course).
     * @sa match_q()
     */
    public function match(s:String) : Bool {
        var search = this.flags.caseSensitive
            ? s
            : s.toLowerCase()
        ;
        for (developed in _expand()) {
            if (this.flags.caseSensitive) {
                if (developed == search) return true;
            }
            else if (developed.toLowerCase() == search)
                return true;
        }
        return false;
    }

    /**
     * Return qualitative best match.
     * @param (filter:S->S) an optional filter for expanded 
     *  expected values. If given, s is evaluated against 
     *  both filtered and unfiltered expansions.
     * @return (Quality) in all cases we return the best 
     *         Quality possible.
     */
    public function match_q( s:String, ?filter:(developed:String, search:String, slre:SLRE)->Either<Quality, QualityError>) : Either<Quality, QualityError> {
        if (s == "") return Left(Empty);
        var search = s;
        var best : Quality = Bad;
        if (filter != null) {
            // filtered doesn't get levenshtein distance evaluation automatically
            for (developed in _expand()) {
                if (developed == search) return Left(Perfect);
                else {
                    switch filter(developed, search, this) {
                        case Left(q):
                            if (q == Perfect) return Left(Perfect);
                            if (q > best) best = q;
                        case Right(qerror):
                            return Right(qerror);
                    }
                }
            }
            return Left(best);
        }
        else {
            // no filter
            if (!this.flags.caseSensitive) {
                search = search.toLowerCase();
            }
            var bestLevenshtein : Int = 99;
            for (developed in _expand()) {
                if (!this.flags.caseSensitive) {
                    developed = developed.toLowerCase();
                }
                if (developed == search) return Left(Perfect);
                else {
                    var lev = Tools.getLevenshteinDistance(developed, search);
                    if (lev < bestLevenshtein) bestLevenshtein = lev;
                }
            }
            // unfound
            if (bestLevenshtein <= 2) return Left(Average);
            else return Left(Bad);
        }
    }

    /**
     * Expand SLRE to all possible strings (modulo case-insensitivity and utf-8
     * equivalence characters).
     *
     * E.g. with a pattern "[this is |here is ]what is {expected|to be typed}",
     *      this function would develop it into: [
     *              "what is expected"
     *              "what is to be typed"
     *              "this is what is expected"
     *              "this is what is to be typed"
     *              "here is what is expected"
     *              "here is what is to be typed"
     *          ]
     *
     * @note you ideally won't need to call this but rather match().
     * @throw (String) when internally called parse() would throw.
     * @sa match()
     */
    @:throw public function _expand() : Array<String> {
        function _reduce(seq:NodeSeq) : Array<String> {
            switch seq {
                case Seq(nodes): // ⊙
                    var terms : Array<Array<String>> = [];
                    for (node in nodes) { // --- e.g. Text ⊙ Alt ⊙ Text ⊙ Alt.
                        switch node {
                            case Text(s):
                                terms.push( [s] );
                            case Alt(branches): // ⧇ 
                                var a : Array<String> = [];
                                for (branch in branches) {
                                    for (x in _reduce((branch)))
                                        a.push(x);
                                }
                                terms.push(a);
                            case Opt(branches):
                                var a : Array<String> = [""];
                                for (branch in branches) {
                                    for (x in _reduce((branch)))
                                        a.push(x);
                                }
                                terms.push(a);
                        }
                    }
                    // end of sequence, we may now fold w/ cartesianproduct
                    var product : Array<String> = [];
                    for (term /*: Array<String>*/ in terms)
                        product = inline cartesianproduct(product, term);
                    return product;
            }
        } // private function _reduce()
        return _expanded == null 
            ? _expanded = _reduce(_parse())
            : _expanded
        ;

    }

    /**
     * You shouldn't need to call it.
     */
    @:throw public function _parse() : NodeSeq {
        // we will use the original parseWithImplicitAlt() and transform it slightly.
        if (this._ast != null) return _ast;
        var devnode : Node = _parseWithImplicitAlt();
        switch devnode {
            case Alt(aseq):
                if (aseq.length == 0) return this._ast = Seq([]);
                if (aseq.length == 1) return this._ast = aseq[0];
                else return this._ast = Seq([ devnode ]);
            case _: throw 'Alt expected instead of ${Std.string(devnode)}';
        }
    }

    /**
     * As they are tokens separated by any amount of space or tab chars,
     *   String inside Text(...) are trimmed, with the exception when it
     *   matches ~/^[ \t]+$/ where an actual Text(" ") 
     *   is used (e.g. in "every[ ]one").
     */
    @:throw public function _parseWithImplicitAlt() : Node {
        var expected = this.pattern;
        if (expected == null) throw "FK49Fajer29";  // watchdog. should not happpen
        if (expected == "") return Alt([Seq([])]);
        var i     = -1;
        var len   = expected.length;
        var buf   = new StringBuf();
        var stack = new List<Node>();               // in the end there should remain only 1 Alt(..) element!
        stack.push(Alt([Seq([])]));

        var wasText = false;
        switch expected.fastCodeAt(0) {
            case "{".code: stack.push(Alt([Seq([])]));         // {color is {gold|silver}|there is no color}
            case "[".code: stack.push(Opt([Seq([])]));
            case "}".code: throw 'Unexpected `}` at $i: ' + _highlight(expected, 0);
            case "]".code: throw 'Unexpected `]` at $i: ' + _highlight(expected, 0);
            case "|".code: throw 'unexpected `|` at $i: ' + _highlight(expected, 0);
            case char: buf.addChar(char);
                       wasText = true;
        }
        i++;
        // if there was only one character, we only accept wasText = true
        // if (expected.length == 1) {
        //     if (!wasText) throw 'Unexpected $expected at 0: ' + _highlight(expected, 0);
        //     else return Alt([Seq([Text(buf.toString())])]);
        // }
        function _seq() : Array<Node> // {{{2
            return switch stack.first() { 
                case Text(_): throw "FKri29";  // watchdoog, should never happen
                case Opt(aseq) | Alt(aseq): switch aseq[aseq.length-1] { case Seq(arr): arr; }
            }; // }}}2
        function _pushBufToSeq() { // {{{2
            _seq().push(Text(buf.toString())); 
            buf = new StringBuf(); 
            wasText = false;
        }; // }}}2
        while (++i < len) {
            if (stack.length > DEFAULTMAXDEPTH) throw 'Too many levels of [] and {}, can not exceed $DEFAULTMAXDEPTH';
            var charcode = expected.fastCodeAt(i);
            // trace(expected.substr(i, 1));
            switch charcode {
                case "{".code: if (wasText) _pushBufToSeq(); stack.push( Alt([Seq([])]) );
                case "[".code: if (wasText) _pushBufToSeq(); stack.push( Opt([Seq([])]) );
                case "}".code
                   | "]".code:
                    if (wasText) _pushBufToSeq();
                    switch stack.first() {
                        case Alt(_) if (charcode == "}".code):
                            var tmp = stack.pop();
                            _seq().push(tmp);
                        case Opt(_) if (charcode == "]".code):
                            var tmp = stack.pop();
                            _seq().push(tmp);
                        default: throw 'Unexpected `${expected.substr(i, 1)}` at $i in: ' + _highlight(expected, i);
                    }
                case "|".code:
                    // `|` marks the end of a Sequence and begin of another one as shown below: {{{2
                    // "gold|yellow"
                    // Following is checked in test_parse_3():
                    // "{the color is {gold|yellow}|there is no color}"
                    // "[the color is {gold|yellow}|there is no color]"
                    //                            ^^-- these cases are interesting...
                    //                                 They suggest we need Seq
                    //                                 within Alt or Opt and that
                    //                                 `|` marks the end of a Sequence
                    //  Alt
                    //     Seq
                    //          "the color is"
                    //          Alt 
                    //              Seq
                    //                  "gold"
                    //              Seq
                    //                  "yellow"
                    //     Seq
                    //          "there is no color"  
                    //
                    // OTOH in:
                    // "hi {there|every one}"
                    // Alt
                    //      Seq
                    //          "hi"
                    //          Alt
                    //              Seq
                    //                  "there"
                    //              Seq
                    //                  "every one"
                    // }}}2
                    if (wasText) _pushBufToSeq();
                    switch stack.first() {
                        case Opt(a)
                           | Alt(a): a.push( Seq([]) );
                        case _: throw 'ERK9g';  // watchdog. should never happen
                    }
                case char: 
                    buf.addChar(char);
                    wasText = true;
            } // switch expected.fastCodeAt(i) 
        } // while not end of string
        // Having arrived at end of string there remain one last thing:
        if (wasText) _seq().push(Text(buf.toString()));
        // Our stack must contain only one element, the initial implicit Alt([...)])
        //                                          that hopefully got feeded
        //                                          with one or more sequences
        if (stack.length != 1) throw 'Some [] or {} where not propery closed in ' + expected;
        else return stack.pop();
    } // _parse()

    static function _highlight(s:String, pos:Int) : String
        #if ansistral
        return s.substr(0, pos) + ansistral.StringAnsi.bold(
                                  ansistral.StringAnsi.red( s.substr(pos, 1)
                                  )) + s.substr(pos+1); 
        #else
        return s.substr(0, pos) + "**" +s.substr(pos, 1) + "**" + s.substr(pos+1); 
        #end

    /**
     * Trim spaces and tabs left and right, with the exception that if it's
     * only spaces and/or tabs in `s`, we'll return " ".
     * E.g. 
     *  "   word  " -> "word"
     *  "   " -> " "
     */
    // static function _specialTrim(s:String) : String
    //     return ~/^[ \t]+$/.match(s)
    //         ? " "
    //         : s.trimChars(" \t")
    //     ;

    /**
     * A n-ary pseudo-cartesian-product (pseudo:
     * when one set is empty we return the other one instead of ⊘).
     * [["a b c"], ["d"], ["e f"]] 
     * -> [ ["a d e"], ["a d f"], ["b d e"], ["b d f"], ["c d e"], ["c d f"] ]
     * @sa cartesianproduct().
     **/
    /* works, but unneeded
    @:throw public static function cartesianproduct_chained<T>(aa:Array<Array<T>>) : Array<Array<T>> {
        // it's easier if we consider A.B.C as A.B and then (A.B).C.
        // Chaining cartesianproduct together is more of a fold() operation,
        // but okay let's do it here.
        if (aa.length == 0) throw "REg3j9";
        var prevProduct : Array<Array<T>> = [ aa[0] ];
        for (i in 1...aa.length) {
            var newProduct : Array<Array<T>> = [];
            for (elt in prevProduct) {
                for (abc in elt) {
                    for (d in aa[i]) {
                        newProduct.push( [abc, d] );
                    } 
                }
            }
            prevProduct = newProduct;
        }
        return  prevProduct ;
    }
    */

    /**
     * A pseudo-cartesian product, that we define as ⊙ operator in our doc.
     * ["a b", "c"] ⊙ ["d"] -> ["a bd", "cd"].
     * And contrarily to a real cartesian product, [] ⊙ x -> x.
     * @sa cartesianproduct_chained().
     **/
    @:throw public static function cartesianproduct<T>(a:Array<String>, b:Array<String>) : Array<String> {
        if (a == null || a.length == 0) return b;
        if (b == null || b.length == 0) return a;
        return [ for (u in a) for (v in b) '$u$v' ];
    }


}

/**
 * Enums for AST parse tree.
 */
enum NodeSeq { Seq(a:Array<Node>); }
enum Node {
    Text(s:String);             // Leaf
    Alt (a:Array<NodeSeq>);     // Alternatives
    Opt (a:Array<NodeSeq>);     // Opt([...]) <=> Alt(["", ...])
}


// vim: fdm=marker
