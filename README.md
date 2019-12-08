We define SLRE as **Simple Linguistic Regular Expressions**. They are much simpler and very different compared to "regexes" such as the BRE, ERE, PCRE...

# First of all, this library uses Haxe

[Haxe](https://www.haxe.org) is a multi-paradigm, multi-target language. Feel free to reimplement those SLRE in another language.

# Scope

Simple Linguistic Regular Expressions (SLRE) come naturally and we give it a formal name here just for the sake of it. 

**Aims** can be defined by the needs:

* to be understandable, **readable** and **writable**, by **regular**, non-computer savvy **users**,
* to be usable on a web server while being [ReDos-safe](https://en.wikipedia.org/wiki/Regular_expression_Denial_of_Service),
* focus on **linguistic** rather than general expression,  
* have some **fuzzy** rather than **boolean** matching, 
* remove regex features such as the Kleene-star, concentrate on fuzzy matching to verify how well an answer matches an expected pattern, including the option for some utf-8 characters to automatically match another (e.g. "e" fuzzily matching "é") **hence "Simple Linguistic" in SLRE**.

## Examples

How easy it is?

It only uses 5 glyphs: `|`, `{`, `}`, `[`, `]` (six with upcoming escape character `\`).

A few examples showing **all there is to know**.

1. `dark|black|shadowed|sunless`: either word is acceptable. But it won't match if anything precedes or follows.
2. `{dark|black} {chocolate|cocoa}`: there are four acceptable answers: "dark chocolate", "black chocolate", "dark cocoa", "black cocoa". 
3. `colo[u]r`: this shows optional alternative, here "color" and "colour" are the only matches.
4. `a [very|quite|somewhat] hot summer`: this time we really have alternatives, and they can be omitted. There are 4 acceptable matches here, including "a hot summer" (which would have given no match if curly brackets had been used).
5. `some part[ completely {optional|up to you}] that you will write yourself`: Nesting is possible.
6. `[Yesterday |Monday ]{[s]he|it} {negligently} drove a {[Mercedes[-| ] ]Benz|Ferrari|Porsche}`: it's possible to write more cumbersome expressions, though it somehow defeats the purpose of SLRE (they are for short expressions, if you expect a match being a very long sentence you wouldn't use neither regex nor SLRE to be frank).

# In the Chomsky hierarchy

A SLRE meets the following characteristics:

* it's a context-free expression,
* it's a regular expression (in Chomsky hierarchy, but it's arguably not a "regex", in the commonly restrictive acception at least),
* it's a non-recursive expression,
* it's counter-free (no Kleene-star, no `+`, no `{min,max}`),
* it's finite: this means it can contain only a finite number of words.

The languages definable with SLRE are therefore described using a [DAFSA](https://en.wikipedia.org/wiki/Deterministic_acyclic_finite_state_automaton), A.K.A. a DAWG (directed acyclic word graph), which is (dramatically I can only suppose) simpler to implement than a DFA or NFA engine. 

# Maintenance bits of doc

> You probably won't need this to merely use SLRE.

Notations: 

- a-k : leaf nodes (these are `String`, not words or chars),
- ⧇ : an `Alt` node . It is notated like this because it builds arrays (`[]`) which are then developed by the ⊙ operator. 
- ⊙ : a `Seq`. A cartesian product operation coupled with a concatenation operation.
- Opt nodes are not shown, because at some point `Opt(x)` is translated to `Alt(["", x]))`

Haxe definitionss:

```haxe
enum NodeSeq { Seq(a:Array<Node>); }
enum Node {
    Text(s:String);             // Leaf
    Alt (a:Array<NodeSeq>);     // Alternatives
    Opt (a:Array<NodeSeq>);     // Opt([...]) <=> Alt(["", ...])
}
```

**Pattern used** below: `{a{h{j|k}|l}c|de}f`. It's simple yet thourough enough.

## AST (parsed tree internal representation)

`{a{h{j|k}|l}c|de}f` is parsed as following AST in Haxe:

```haxe
Seq([
    Alt([
        Seq([ 
              Text("a"), 
              Alt([
                  Seq([ 
                      Text("h"), 
                      Alt([
                          Seq([ Text("j") ]), 
                          Seq([ Text("k") ])
                      ])
                  ]),
                  Seq([ Text("l") ])
              ]),
              Text("c") 
        ]),
        Seq([ Text("d"), Text("e") ])          
    ]), 
    Text("f")
])
```

## Sequence of cartesian products

To help visualizing the _expand() algorithm, and justify the need of `Seq` and `Alt`, notice we can represent **Pattern** `{a{h{j|k}|l}c|de}f` as:

```
    |                       |
    |      |         |      |         
    |      |         |      |         
    |      | h ⊙ |j| |      |
    |      |     |k| |      |
    |  a ⊙ |         | ⊙ c  |           
    |      |         |      |
X = |      |         |      |  ⊙ f
    |      |    l    |      |
    |      |         |      |
    |      |         |      |
    |                       |
    |                       |
    |     d     ⊙    e      |
    |                       |
```

Between vertical bars are terms of an alternation, **vertically stacked**. There are 3 alternations here and the third one, which 2nd term is `d ⊙ e`, is a little bit hard to see. 

If it's still not clear how it works, the first one is easiest, see `[j,k]` in : `h ⊙ [j,k]`.

This X develops as shown before as `["ahjcf","ahkcf","alcf","def"]`.

## Parsed tree graph

(with annotations preceding nodes, e.g. or `1⧇` or `2⊙` `{a{h{j|k}|l}c|de}f` is parsed as:
```
       0⊙
       / \
     1⧇   ⊙
     / \  |
   2⊙  3⊙ f
   /|\  |\
  a4⧇ c d e
   / \        From bottom, going back up:
 5⊙   ⊙
 / \  |       6⧇ is ["j"] ⊙ ["k"] is ["j", "k"] 
 h6⧇  i       5⊙ is [["h"], ["j", "k"]]
  / \            is ["h j", "h k"] 
 ⊙   ⊙        4⧇ is 5⊙: ["h j", "hk"] ⊙ ["l"]
 |   |           is ["h j", "h k", "l"]  Beware here!! 
              3⊙ is ["d e"]
 j   k        2⊙ is [["a"], ["h j", "h k", "l"], ["c"]]
                 is ["ahjc","ahkc","alc"]
              1⧇ is 1⊙ ⧇ 2⊙
                 is 1⊙: ["ahjc","ahkc","alc"]
                    2⊙: ["de"]
                 is ["ahjc","ahkc","alc", "de"]
              0⊙ is [["ahjc","ahkc","alc", "de"], ["f"]]
                 is ["ahjcf","ahkcf","alcf","def"].

Expansion:

After putting this together we start to see the dance between ⊙ and ⧇ (Seq and Alt):
⧇ folds all (reduced) branches to a mere Array<String>.
  (note ⊙ DOES the String concat, NOT ⧇ ),
⊙ has an internal work var of Array<Array<String>>,
  which then gets developed (using String concat variant of a cartesian product).
  and returns Array<String>.
```

