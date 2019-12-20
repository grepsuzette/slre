package test;

import grepsuzette.slre.SLRE;
import grepsuzette.slre.Tools.stripAccents as stripAccents;
using test.TestSLRE;            // for the 2 last methods

// @:access(grepsuzette.slre.SLRE._specialTrim)
class TestSLRE extends haxe.unit.TestCase {

    public static function main() {
        var runner = new haxe.unit.TestRunner();
        runner.add(new TestSLRE());
        runner.run();
    }

    public static function parse(patt:String) 
        return SLRE.create(patt)._parse();
    

    public static function expand(patt:String) 
        return SLRE.create(patt)._expand();
    

    public function test_stripAccents() : Void {
        assertEquals(stripAccents("läéñÿ"), "laeny");
        assertEquals(stripAccents("MÖtörhēād"), "MOtorhead");
    }


    public function test_random() : Void {
        var slre = new SLRE("{blue|jazzy} note");
        var r = 100;
        for (i in 0...100) {
            switch slre.random() {
                case "blue note": r++;
                case "jazzy note": r--;
                case xxx: trace(xxx); assertFalse(true);
            }
        }
        assertTrue(r > 10);
        assertTrue(r < 190);
    }

    public function test_random2() : Void {
        var slre = new SLRE("{blue|jazzy} note");
        var r = 100;
        for (i in 0...100) {
            switch slre.random(true) { // always the same
                case "blue note": r++;
                case "jazzy note": r--;
                case xxx: trace(xxx); assertFalse(true);
            }
        }
        assertTrue(r > 190 || r < 10);
    }

    // public function test_specialTrim() : Void {
    //     assertEquals(SLRE._specialTrim("Hi"), "Hi");
    //     assertEquals(SLRE._specialTrim("Hi "), "Hi");
    //     assertEquals(SLRE._specialTrim("Hi  "), "Hi");
    //     assertEquals(SLRE._specialTrim("Hi  \t "), "Hi");
    //     assertEquals(SLRE._specialTrim(" Hi  \t "), "Hi");
    //     assertEquals(SLRE._specialTrim("\t Hi  \t "), "Hi");
    //     assertEquals(SLRE._specialTrim(" \t Hi  \t "), "Hi");
    //     assertEquals(SLRE._specialTrim(" \t   \t "), " ");
    //     assertEquals(SLRE._specialTrim(" "), " ");
    //     assertEquals(SLRE._specialTrim("  "), " ");
    //     assertEquals(SLRE._specialTrim(""), "");
    // }

    // public function test_cartesianproduct_chained() : Void {
    //     switch SLRE.cartesianproduct_chained([["a", "b"], ["c"]]) {
    //         case [["a", "c"], ["b", "c"]]: assertTrue(true);
    //         case _: assertFalse(true);
    //     }
    // } 

    public function test_cartesianproduct() : Void {
        switch SLRE.cartesianproduct(["a b"], ["c"]) {
            case ["a bc"]: assertTrue(true);
            case _: assertFalse(true);
        }

        switch SLRE.cartesianproduct(["a b"], ["c", "d"]) {
            case ["a bc", "a bd"]: assertTrue(true);
            case _: assertFalse(true);
        }
    } 

    public function test_parse_errors() : Void {
        try switch parse(null) {
            case _: assertTrue(false);
        } catch (d:Dynamic) assertTrue(true);
        try switch parse("|") {
            case _: assertTrue(false);
        } catch (d:Dynamic) assertTrue(true);
        try switch parse("}") {
            case _: assertTrue(false);
        } catch (d:Dynamic) assertTrue(true);
        try switch parse("]") {
            case _: assertTrue(false);
        } catch (d:Dynamic) assertTrue(true);
        try switch parse("{mismatch]") {
            case _: assertTrue(false);
        } catch (d:Dynamic) assertTrue(true);
        try switch parse("{{mismatch|unbalanced}]") {
            case _: assertTrue(false);
        } catch (d:Dynamic) assertTrue(true);
        try switch parse("{{mismatch|unbalanced}|tudor|{unbalanced}") {
            case _: assertTrue(false);
        } catch (d:Dynamic) assertTrue(true);
    }

    public function test_parse_1() : Void {
        switch parse("") {
            case Seq([]): assertTrue(true);
            case something: trace('Unexpectedly parsed as:\n$something'); assertTrue(false);
        }
        switch parse("hi") {
            case Seq([Text("hi")]): assertTrue(true);
            case something: trace('Unexpectedly parsed as:\n$something'); assertTrue(false);
        }
        switch parse("hi [there]") {
            case Seq([ Text("hi "), Opt([Seq([Text("there")])]) ]): assertTrue(true);
            case something: trace('Unexpectedly parsed as:\n$something'); assertTrue(false);
        }
        switch parse("hi {there}") {
            case Seq([Text("hi "), Alt([Seq([Text("there")])])]): assertTrue(true);
            case something: trace('Unexpectedly parsed as:\n$something'); assertTrue(false);
        }
    }

    // implicit top-level alternation activated
    public function test_parse_0() : Void {
        switch parse("hi|hello") {
            case Seq([ Alt([ Seq([ Text("hi") ]), Seq([ Text("hello") ]) ]) ]): assertTrue(true);
            case something: trace('Unexpectedly parsed as:\n$something'); assertTrue(false);
        }
    }

    // alternations
    public function test_parse_2() : Void {
        switch parse("a {gold|golden} color") {
            case Seq([Text("a "), Alt([ Seq([Text("gold")]), Seq([Text("golden")]) ]), Text(" color")]): assertTrue(true);
            case something: trace('Unexpectedly parsed as:\n$something'); assertTrue(false);
        }
        switch parse("a [gold|golden] color") {
            case Seq([Text("a "), Opt([ Seq([Text("gold")]), Seq([Text("golden")]) ]), Text(" color")]): assertTrue(true);
            case something: trace('Unexpectedly parsed as:\n$something'); assertTrue(false);
        }
        switch parse("hi {there|every one}") {
            case Seq([Text("hi "), Alt([Seq([Text("there")]), Seq([Text("every one")])])]): assertTrue(true);
            case something: trace('Unexpectedly parsed as:\n$something'); assertTrue(false);
        }
        switch parse("I am [{very|quite} glad]") {
            case Seq([Text("I am "), 
                           Opt([Seq([
                                    Alt([
                                        Seq([Text("very")]),
                                        Seq([Text("quite")]),
                                    ]),
                                    Text(" glad")
                    ])])]): assertTrue(true); 
            case something: trace('Unexpectedly parsed as:\n$something'); assertTrue(false);
        }
        switch parse("hi {there|every[ ]one}") {
            case Seq([Text("hi "), Alt([Seq([Text("there")]), 
                                             Seq([
                                                Text("every"),
                                                Opt([ Seq([ Text(" ") ]) ]),
                                                Text("one")
                                             ])
                                            ])]): assertTrue(true);
            case something: trace('Unexpectedly parsed as:\n$something'); assertTrue(false);
        }
        switch parse("some part[ completely {optional|up to you}] that you will write yourself") {
            case Seq([
                Text("some part"),
                Opt([
                    Seq([
                        Text(" completely "),
                        Alt([
                            Seq([ Text("optional") ]),
                            Seq([ Text("up to you") ]),
                        ]),
                    ])
                ]),
                Text(" that you will write yourself"),
            ]): assertTrue(true);
            case something: trace('Unexpectedly parsed as:\n$something'); assertTrue(false);
        }
    }

    // alternations with some "}|" or "]|" appearing
    public function test_parse_3() : Void {
        switch parse("{the color is {gold|yellow}|there is no color}") {
            case Seq([
                Alt([
                    Seq([
                        Text("the color is "),
                        Alt([ Seq([Text("gold")]), Seq([Text("yellow")]) ])
                    ]),
                    Seq([ Text("there is no color") ])
                ])
            ]): assertTrue(true);
            case something: trace('Unexpectedly parsed as:\n$something'); assertTrue(false);
        }
        switch parse("[the color is {gold|yellow}|there is no color]") {
            case Seq([  
                Opt([
                    Seq([
                        Text("the color is "),
                        Alt([ Seq([Text("gold")]), Seq([Text("yellow")]) ])
                    ]),
                    Seq([ Text("there is no color") ])
                ])
            ]): assertTrue(true);
            case something: trace('Unexpectedly parsed as:\n$something'); assertTrue(false);
        }
        switch parse("[the color is [gold|yellow]|there is no color]") {
            case Seq([  
                Opt([
                    Seq([
                        Text("the color is "),
                        Opt([ Seq([Text("gold")]), Seq([Text("yellow")]) ])
                    ]),
                    Seq([ Text("there is no color") ])
                ])
            ]): assertTrue(true);
            case something: trace('Unexpectedly parsed as:\n$something'); assertTrue(false);
        }
        switch parse("{the color is [gold|yellow]|there is no color}") {
            case Seq([  
                            Alt([
                                Seq([
                                    Text("the color is "),
                                    Opt([ Seq([Text("gold")]), Seq([Text("yellow")]) ])
                                ]),
                                Seq([ Text("there is no color") ])
                            ])
            ]): assertTrue(true);
            case something: trace('Unexpectedly parsed as:\n$something'); assertTrue(false);
        }
    }

    public function test_expand() : Void {
        assertEquals(
            expand("some part{ not| not really} optional").join("＆"),
            [ "some part not optional", "some part not really optional" ].join("＆")
        );
        assertEquals(
            expand("some part[ completely] optional").join("＆"),
            [ "some part optional", "some part completely optional" ].join("＆")
        );
        assertEquals(
            expand("some part[ completely| pretty much] optional").join("＆"),
            [ "some part optional", "some part completely optional", "some part pretty much optional" ].join("＆")
        );
        assertEquals(
            expand("some part[ completely| {pretty|very} much] optional").join("＆"),
            [ "some part optional", "some part completely optional", "some part pretty much optional", "some part very much optional" ].join("＆")
        );
        assertEquals(
            expand("blue|green|orange").join("＆"),
            [ "blue", "green", "orange" ].join("＆")
        );
        assertEquals(
            expand("[Yesterday |Monday ]{[s]he|it} drove a {[Mercedes ]Benz|Ferrari|Porsche}").sort_with_return(fsort_string).join("＆"),
            [
                "he drove a Benz",
                "she drove a Benz",
                "it drove a Benz",
                "he drove a Mercedes Benz",
                "she drove a Mercedes Benz",
                "it drove a Mercedes Benz",
                "he drove a Ferrari",
                "she drove a Ferrari",
                "it drove a Ferrari",
                "he drove a Porsche",
                "she drove a Porsche",
                "it drove a Porsche",

                "Yesterday he drove a Benz",
                "Yesterday she drove a Benz",
                "Yesterday it drove a Benz",
                "Yesterday he drove a Mercedes Benz",
                "Yesterday she drove a Mercedes Benz",
                "Yesterday it drove a Mercedes Benz",
                "Yesterday he drove a Ferrari",
                "Yesterday she drove a Ferrari",
                "Yesterday it drove a Ferrari",
                "Yesterday he drove a Porsche",
                "Yesterday she drove a Porsche",
                "Yesterday it drove a Porsche",

                "Monday he drove a Benz",
                "Monday she drove a Benz",
                "Monday it drove a Benz",
                "Monday he drove a Mercedes Benz",
                "Monday she drove a Mercedes Benz",
                "Monday it drove a Mercedes Benz",
                "Monday he drove a Ferrari",
                "Monday she drove a Ferrari",
                "Monday it drove a Ferrari",
                "Monday he drove a Porsche",
                "Monday she drove a Porsche",
                "Monday it drove a Porsche",

            ].sort_with_return(fsort_string).join("＆")
        );
        assertEquals(
            expand("[Yesterday|Monday]|Today").join("＆"),
            [ "", "Yesterday", "Monday", "Today" ].join("＆")
        );
    }

    public static function sort_with_return<T>(a:Array<T>, f:T->T->Int) : Array<T> {
        a.sort(f);
        return a;
    } 

    public static function fsort_string(s1:String, s2:String) : Int {
        return s1 < s2 ? -1 : s1 > s2 ? 1 : 0;
    }


}
