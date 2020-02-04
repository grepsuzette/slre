package grepsuzette.slre;

import Iso639_1 as Lg;
using StringTools;

class Tools {


    /**
     * A very weak but fast and easy to use
     * function stripping away diacritics.
     *
     * Since Haxe is using UCS-2 and not UTF-8
     * (at least on targets hxcpp, js, HashLink, eval, ..
     * BUT NOT neko as of December 12, 2019 (no Unicode on neko))
     * we should be able to use the conversion below without
     * going through the more complex processes known as NFKC
     * (normalization form compatibility composition), which 
     * would be nice because, haha. it's a real pita.
     * https://en.wikipedia.org/wiki/Unicode_equivalence
     *
     * @param (String) The string to strip accents from
     * @param (Iso639_1 lg) [Maybe] if a language is provided,
     *                      only diacritic for this language
     *                      may be removed, allowing
     *                      faster operation.
     * @return (String) "läéñÿ" -> "laeny"
     */
    public static function stripAccents(s:String /*, lg:Lg=null */):String{
        if (s == null || s == "") return "";
        var bCharOver127 = false;
        for (i in 0...s.length) if (s.fastCodeAt(i) > 127) bCharOver127 = true;
        if (!bCharOver127) return s;
        #if !target.unicode
            #if (sys)
                // TODO check if we are on linux or iconv (or uconv) exists
                var pr = new sys.io.Process("iconv -f UTF-8 -t ASCII//TRANSLIT");
                pr.stdin.writeString(s, RawNative);
                pr.stdin.close();
                while ( null == pr.exitCode(true) ) Sys.sleep(0.0015);
                var s = pr.stdout.readLine();
                pr.close();
                return s;
            #else
                #error "stripAccents necessitates a platform supporting Unicode. https://haxe.org/manual/std-String-unicode.html"
            #end
        #else
        // TODO Warning, this is untested yet
        var buf = new StringBuf();
        // for (ch in new haxe.iterators.StringIteratorUnicode(s)) { // 0...s.length) {
        for (i in 0...s.length) {
            // trace(i);
            // trace(s.charAt(i));
            // buf.add(switch ch {
            buf.add(switch s.charAt(i) {
                // These hopefully should cover most latin languages:
                //   english, french, german, dutch, 
                //   italian, portuguese, spanish, swedish, catalan,
                //   lithuanian(is it latin?), maltese, welsch
                // https://en.wikipedia.org/wiki/Diacritic#Other_languages

                // grave  circ  acute caron macron diae tild
                case "á" | "â" | "à" | "ǎ" | "ā" | "ä"  | "ã": "a";
                case "é" | "ê" | "è" | "ě" | "ē" | "ë"       : "e";
                case "í" | "î" | "ì" | "ǐ" | "ī" | "ï"       : "i";
                case "ó" | "ô" | "ò" | "ǒ" | "ō" | "ö"  | "õ": "o";
                case "ú" | "û" | "ù" | "ǔ" | "ū" | "ü"       : "u";
                case "ẃ" | "ŵ" | "ẁ" |             "ẅ"       : "w"; // welsch 
                case "ý" | "ŷ" | "ỳ" | /**/        "ÿ"       : "y";
                case "Á" | "Â" | "À" | "Ǎ" | "Ā" | "Ä"  | "Ã": "A";
                case "É" | "Ê" | "È" | "Ě" | "Ē" | "Ë"       : "E";
                case "Í" | "Î" | "Ì" | "Ǐ" | "Ī" | "Ï"       : "I";
                case "Ó" | "Ô" | "Ò" | "Ǒ" | "Ō" | "Ö"  | "Õ": "O";
                case "Ú" | "Û" | "Ù" | "Ǔ" | "Ū" | "Ü"       : "U";
                case "Ý" | "Ŷ" | "Ỳ" | /**/        "Ÿ"       : "Y";
                case "Ẃ" | "Ŵ" | "Ẁ" |             "Ẅ"       : "W"; // welsch
                case "å": "a";    // a WITH RING ABOVE (as in swedish)
                case "Å": "A";    // A WITH RING ABOVE (as in swedish)
                case "ñ": "n";
                case "š": "s";    // carons in s and z appear in finnish
                case "ž": "z";    // carons in s and z appear in finnish
                case "¿" | "⋅": "";
                case "Œ": "Oe";
                case "œ": "oe";
                case "Æ": "Ae";
                case "æ": "ae";
                case "ç": "c";
                case "ß": "ss";
                case xxx : xxx;
            });
        }
        return buf.toString();
        #end
    }

    /**
     * Calculates the Levenshtein distance between the given strings.
     *
     * This is the number of single character modification (deletion, insertion, or
     * substitution) needed to change one string into another.
     *
     * See https://en.wikipedia.org/wiki/Levenshtein_distance
     * Based on https://commons.apache.org/proper/commons-lang/javadocs/api-3.4/org/apache/commons/lang3/StringUtils.html#getLevenshteinDistance(java.lang.CharSequence,%20java.lang.CharSequence)
     */
    public static function getLevenshteinDistance(left:String, right:String):Int 
    #if haxe_strings
        return hx.strings.Strings.getLevenshteinDistance(left, right);
    #else
    {
        // Copied from hx-strings (reimplementation if haxe-strings is not used)
        // Copyright (c) 2016-2018 Vegard IT GmbH, https://vegardit.com
        // SPDX-License-Identifier: Apache-2.0
        var leftLen = left.length;
        var rightLen = right.length;
        if (leftLen == 0) return rightLen;
        if (rightLen == 0) return leftLen;
        if (leftLen > rightLen) {
            // swap the input strings to consume less memory
            var tmp    = left;
            left       = right;
            right      = tmp;
            var tmpLen = leftLen;
            leftLen    = rightLen;
            rightLen   = tmpLen;
        }
        var prevCosts = new Array<Int>();
        var costs = new Array<Int>();
        for (leftIdx in 0...leftLen + 1) {
            prevCosts.push(leftIdx);
            costs.push(0);
        }
        var leftChars = left.split("").map(s -> s.charCodeAt(0));
        var rightChars = right.split("").map(s -> s.charCodeAt(0));
        var min = function(a:Int, b:Int) return a > b ? b : a;
        for (rightIdx in 1...rightLen + 1) {
            var rightChar = rightChars[rightIdx - 1];
            costs[0] = rightIdx;
            for (leftIdx in 1...leftLen + 1) {
                var leftIdxMinus1 = leftIdx - 1;
                var cost          = leftChars[leftIdxMinus1] == rightChar ? 0 : 1;
                costs[leftIdx]    = min(min(costs[leftIdxMinus1] + 1, prevCosts[leftIdx] + 1), prevCosts[leftIdxMinus1] + cost);
            }
            var tmp   = prevCosts;
            prevCosts = costs;
            costs     = tmp;
        }
        return prevCosts[leftLen];
    }
    #end
    
}
