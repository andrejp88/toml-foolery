/++
This module was automatically generated from the following grammar:

#; This document describes TOML's syntax, using the ABNF format (defined in
#; RFC 5234 -- https://www.ietf.org/rfc/rfc5234.txt).
#;
#; All valid TOML documents will match this description, however certain
#; invalid documents would need to be rejected as per the semantics described
#; in the supporting text description.

#; It is possible to try this grammar interactively, using instaparse.
#;     http://instaparse.mojombo.com/
#;
#; To do so, in the lower right, click on Options and change `:input-format` to
#; ':abnf'. Then paste this entire ABNF document into the grammar entry box
#; (above the options). Then you can type or paste a sample TOML document into
#; the beige box on the left. Tada!

#; Overall Structure


TomlGrammar:

toml             <- expression ( newline expression )* :eoi

expression       <- ws table ws ( comment )? / ws keyval ws ( comment )? / ws ( comment )?

#; Whitespace

ws               <- wschar*
wschar           <-  [ ]  /  [\t]   # Space / Horizontal tab

#; Newline

newline          <:  [\n]  /  [\r]   [\n]   # LF / CRLF

#; Comment

comment_start_symbol <-  [#]  # #
non_ascii        <-  [\x80-\uD7FF]  /  [\uE000-\U0010FFFF]
non_eol          <-  [\t]  /  [ -~]  / non_ascii

comment          <- comment_start_symbol non_eol*

#; Key-Value pairs

keyval           <- key keyval_sep val

key              <- dotted_key / simple_key
simple_key       <- quoted_key / unquoted_key

unquoted_key     <- ( ALPHA / DIGIT /  [-]  /  [_]  )+ # A-Z / a-z / 0-9 / - / _
quoted_key       <- basic_string / literal_string
dotted_key       <- simple_key ( dot_sep simple_key )+

dot_sep          <- ws  [.]  ws  # . Period
keyval_sep       <- ws  [=]  ws # =

val              <- string_ / boolean / array / inline_table / date_time / float_ / integer

#; String

string_          <- ml_basic_string / basic_string / ml_literal_string / literal_string

#; Basic String

basic_string     <- quotation_mark basic_char* quotation_mark

quotation_mark   <-  ["]             # "

basic_char       <- basic_unescaped / escaped
basic_unescaped  <- wschar /  [!]  /  [#-\[]  /  [\]-~]  / non_ascii
escaped          <- escape escape_seq_char

escape           <-  [\\]                    # \

# %x22              "    quotation mark  U+0022
# %x5C              \    reverse solidus U+005C
# %x62              b    backspace       U+0008
# %x66              f    form feed       U+000C
# %x6E              n    line feed       U+000A
# %x72              r    carriage return U+000D
# %x74              t    tab             U+0009
# %x75 4HEXDIG      uXXXX                U+XXXX
# %x55 8HEXDIG      UXXXXXXXX            U+XXXXXXXX
escape_seq_char  <-  ["]  /  [\\]  /  [b]  /  [f]  /  [n]  /  [r]  /  [t]  /  [u]  HEXDIG HEXDIG HEXDIG HEXDIG /  [U]  HEXDIG HEXDIG HEXDIG HEXDIG HEXDIG HEXDIG HEXDIG HEXDIG

#; Multiline Basic String

ml_basic_string  <- ml_basic_string_delim ( newline )? ml_basic_body
                  ml_basic_string_delim
ml_basic_string_delim <- quotation_mark quotation_mark quotation_mark
ml_basic_body    <- mlb_content* ( mlb_quotes mlb_content+ )* ( mlb_quotes )?

mlb_content      <- mlb_char / newline / mlb_escaped_nl
mlb_char         <- mlb_unescaped / escaped
mlb_quotes       <- quotation_mark quotation_mark? !quotation_mark
mlb_unescaped    <- wschar /  [!]  /  [#-\[]  /  [\]-~]  / non_ascii
mlb_escaped_nl   <- escape ws newline ( wschar / newline )*

#; Literal String

literal_string   <- apostrophe literal_char* apostrophe

apostrophe       <-  [']  # ' apostrophe

literal_char     <-  [\t]  /  [ -&]  /  [(-~]  / non_ascii

#; Multiline Literal String

ml_literal_string <- ml_literal_string_delim ( newline )? ml_literal_body
                    ml_literal_string_delim
ml_literal_string_delim <- apostrophe apostrophe apostrophe
ml_literal_body  <- mll_content* ( mll_quotes mll_content+ )* ( mll_quotes )?

mll_content      <- mll_char / newline
mll_char         <-  [\t]  /  [ -&]  /  [(-~]  / non_ascii
mll_quotes       <- apostrophe apostrophe? !apostrophe

#; Integer

integer          <- hex_int / oct_int / bin_int / dec_int

minus            <-  [-]                        # -
plus             <-  [+]                         # +
underscore       <-  [_]                   # _
digit1_9         <-  [1-9]                  # 1-9
digit0_7         <-  [0-7]                  # 0-7
digit0_1         <-  [0-1]                  # 0-1

hex_prefix       <- "0x"               # 0x
oct_prefix       <- "0o"               # 0o
bin_prefix       <- "0b"               # 0b

dec_int          <- ( minus / plus )? unsigned_dec_int
unsigned_dec_int <- digit1_9 ( DIGIT / underscore DIGIT )+ / DIGIT

hex_int          <- hex_prefix HEXDIG ( HEXDIG / underscore HEXDIG )*
oct_int          <- oct_prefix digit0_7 ( digit0_7 / underscore digit0_7 )*
bin_int          <- bin_prefix digit0_1 ( digit0_1 / underscore digit0_1 )*

#; Float

float_           <- float_int_part ( exp / frac ( exp )? ) / special_float

float_int_part   <- dec_int
frac             <- decimal_point zero_prefixable_int
decimal_point    <-  [.]                # .
zero_prefixable_int <- DIGIT ( DIGIT / underscore DIGIT )*

exp              <- "e" float_exp_part
float_exp_part   <- ( minus / plus )? zero_prefixable_int

special_float    <- ( minus / plus )? ( inf / nan )
inf              <- "inf"  # inf
nan              <- "nan"  # nan

#; Boolean

boolean          <- true_ / false_

true_            <- "true"     # true
false_           <- "false"  # false

#; Date and Time (as defined in RFC 3339)

date_time        <- offset_date_time / local_date_time / local_date / local_time

date_fullyear    <- DIGIT DIGIT DIGIT DIGIT
date_month       <- DIGIT DIGIT  # 01-12
date_mday        <- DIGIT DIGIT  # 01-28, 01-29, 01-30, 01-31 based on month/year
time_delim       <- "T" /  [ ]  # T, t, or space
time_hour        <- DIGIT DIGIT  # 00-23
time_minute      <- DIGIT DIGIT  # 00-59
time_second      <- DIGIT DIGIT  # 00-58, 00-59, 00-60 based on leap second rules
time_secfrac     <- "." DIGIT+
time_numoffset   <- ( "+" / "-" ) time_hour ":" time_minute
time_offset      <- "Z" / time_numoffset

partial_time     <- time_hour ":" time_minute ":" time_second ( time_secfrac )?
full_date        <- date_fullyear "-" date_month "-" date_mday
full_time        <- partial_time time_offset

#; Offset Date-Time

offset_date_time <- full_date time_delim full_time

#; Local Date-Time

local_date_time  <- full_date time_delim partial_time

#; Local Date

local_date       <- full_date

#; Local Time

local_time       <- partial_time

#; Array

array            <- array_open ( array_values )? ws_comment_newline array_close

array_open       <-  [\[]  # [
array_close      <-  [\]]  # ]

array_values     <- ws_comment_newline val ws_comment_newline array_sep array_values / ws_comment_newline val ws_comment_newline ( array_sep )?

array_sep        <-  [,]   # , Comma

ws_comment_newline <- ( wschar / ( comment )? newline )*

#; Table

table            <- std_table / array_table

#; Standard Table

std_table        <- std_table_open key std_table_close

std_table_open   <-  [\[]  ws     # [ Left square bracket
std_table_close  <- ws  [\]]      # ] Right square bracket

#; Inline Table

inline_table     <- inline_table_open ( inline_table_keyvals )? inline_table_close

inline_table_open <-  [{]  ws     # {
inline_table_close <- ws  [}]      # }
inline_table_sep <- ws  [,]  ws  # , Comma

inline_table_keyvals <- keyval ( inline_table_sep inline_table_keyvals )?

#; Array Table

array_table      <- array_table_open key array_table_close

array_table_open <- "[[" ws  # [[ Double left square bracket
array_table_close <- ws "]]"  # ]] Double right square bracket

#; Built-in ABNF terms, reproduced here for clarity

ALPHA            <-  [A-Z]  /  [a-z]  # A-Z / a-z
DIGIT            <-  [0-9]  # 0-9
HEXDIG           <- DIGIT / [A-Fa-f]


+/
module toml_foolery.decode.peg_grammar;

public import pegged.peg;
import std.algorithm: startsWith;
import std.functional: toDelegate;

struct GenericTomlGrammar(TParseTree)
{
    import std.functional : toDelegate;
    import pegged.dynamic.grammar;
    static import pegged.peg;
    struct TomlGrammar
    {
    enum name = "TomlGrammar";
    static ParseTree delegate(ParseTree)[string] before;
    static ParseTree delegate(ParseTree)[string] after;
    static ParseTree delegate(ParseTree)[string] rules;
    import std.typecons:Tuple, tuple;
    static TParseTree[Tuple!(string, size_t)] memo;
    static this()
    {
        rules["toml"] = toDelegate(&toml);
        rules["expression"] = toDelegate(&expression);
        rules["ws"] = toDelegate(&ws);
        rules["wschar"] = toDelegate(&wschar);
        rules["newline"] = toDelegate(&newline);
        rules["comment_start_symbol"] = toDelegate(&comment_start_symbol);
        rules["non_ascii"] = toDelegate(&non_ascii);
        rules["non_eol"] = toDelegate(&non_eol);
        rules["comment"] = toDelegate(&comment);
        rules["keyval"] = toDelegate(&keyval);
        rules["key"] = toDelegate(&key);
        rules["simple_key"] = toDelegate(&simple_key);
        rules["unquoted_key"] = toDelegate(&unquoted_key);
        rules["quoted_key"] = toDelegate(&quoted_key);
        rules["dotted_key"] = toDelegate(&dotted_key);
        rules["dot_sep"] = toDelegate(&dot_sep);
        rules["keyval_sep"] = toDelegate(&keyval_sep);
        rules["val"] = toDelegate(&val);
        rules["string_"] = toDelegate(&string_);
        rules["basic_string"] = toDelegate(&basic_string);
        rules["quotation_mark"] = toDelegate(&quotation_mark);
        rules["basic_char"] = toDelegate(&basic_char);
        rules["basic_unescaped"] = toDelegate(&basic_unescaped);
        rules["escaped"] = toDelegate(&escaped);
        rules["escape"] = toDelegate(&escape);
        rules["escape_seq_char"] = toDelegate(&escape_seq_char);
        rules["ml_basic_string"] = toDelegate(&ml_basic_string);
        rules["ml_basic_string_delim"] = toDelegate(&ml_basic_string_delim);
        rules["ml_basic_body"] = toDelegate(&ml_basic_body);
        rules["mlb_content"] = toDelegate(&mlb_content);
        rules["mlb_char"] = toDelegate(&mlb_char);
        rules["mlb_quotes"] = toDelegate(&mlb_quotes);
        rules["mlb_unescaped"] = toDelegate(&mlb_unescaped);
        rules["mlb_escaped_nl"] = toDelegate(&mlb_escaped_nl);
        rules["literal_string"] = toDelegate(&literal_string);
        rules["apostrophe"] = toDelegate(&apostrophe);
        rules["literal_char"] = toDelegate(&literal_char);
        rules["ml_literal_string"] = toDelegate(&ml_literal_string);
        rules["ml_literal_string_delim"] = toDelegate(&ml_literal_string_delim);
        rules["ml_literal_body"] = toDelegate(&ml_literal_body);
        rules["mll_content"] = toDelegate(&mll_content);
        rules["mll_char"] = toDelegate(&mll_char);
        rules["mll_quotes"] = toDelegate(&mll_quotes);
        rules["integer"] = toDelegate(&integer);
        rules["minus"] = toDelegate(&minus);
        rules["plus"] = toDelegate(&plus);
        rules["underscore"] = toDelegate(&underscore);
        rules["digit1_9"] = toDelegate(&digit1_9);
        rules["digit0_7"] = toDelegate(&digit0_7);
        rules["digit0_1"] = toDelegate(&digit0_1);
        rules["hex_prefix"] = toDelegate(&hex_prefix);
        rules["oct_prefix"] = toDelegate(&oct_prefix);
        rules["bin_prefix"] = toDelegate(&bin_prefix);
        rules["dec_int"] = toDelegate(&dec_int);
        rules["unsigned_dec_int"] = toDelegate(&unsigned_dec_int);
        rules["hex_int"] = toDelegate(&hex_int);
        rules["oct_int"] = toDelegate(&oct_int);
        rules["bin_int"] = toDelegate(&bin_int);
        rules["float_"] = toDelegate(&float_);
        rules["float_int_part"] = toDelegate(&float_int_part);
        rules["frac"] = toDelegate(&frac);
        rules["decimal_point"] = toDelegate(&decimal_point);
        rules["zero_prefixable_int"] = toDelegate(&zero_prefixable_int);
        rules["exp"] = toDelegate(&exp);
        rules["float_exp_part"] = toDelegate(&float_exp_part);
        rules["special_float"] = toDelegate(&special_float);
        rules["inf"] = toDelegate(&inf);
        rules["nan"] = toDelegate(&nan);
        rules["boolean"] = toDelegate(&boolean);
        rules["true_"] = toDelegate(&true_);
        rules["false_"] = toDelegate(&false_);
        rules["date_time"] = toDelegate(&date_time);
        rules["date_fullyear"] = toDelegate(&date_fullyear);
        rules["date_month"] = toDelegate(&date_month);
        rules["date_mday"] = toDelegate(&date_mday);
        rules["time_delim"] = toDelegate(&time_delim);
        rules["time_hour"] = toDelegate(&time_hour);
        rules["time_minute"] = toDelegate(&time_minute);
        rules["time_second"] = toDelegate(&time_second);
        rules["time_secfrac"] = toDelegate(&time_secfrac);
        rules["time_numoffset"] = toDelegate(&time_numoffset);
        rules["time_offset"] = toDelegate(&time_offset);
        rules["partial_time"] = toDelegate(&partial_time);
        rules["full_date"] = toDelegate(&full_date);
        rules["full_time"] = toDelegate(&full_time);
        rules["offset_date_time"] = toDelegate(&offset_date_time);
        rules["local_date_time"] = toDelegate(&local_date_time);
        rules["local_date"] = toDelegate(&local_date);
        rules["local_time"] = toDelegate(&local_time);
        rules["array"] = toDelegate(&array);
        rules["array_open"] = toDelegate(&array_open);
        rules["array_close"] = toDelegate(&array_close);
        rules["array_values"] = toDelegate(&array_values);
        rules["array_sep"] = toDelegate(&array_sep);
        rules["ws_comment_newline"] = toDelegate(&ws_comment_newline);
        rules["table"] = toDelegate(&table);
        rules["std_table"] = toDelegate(&std_table);
        rules["std_table_open"] = toDelegate(&std_table_open);
        rules["std_table_close"] = toDelegate(&std_table_close);
        rules["inline_table"] = toDelegate(&inline_table);
        rules["inline_table_open"] = toDelegate(&inline_table_open);
        rules["inline_table_close"] = toDelegate(&inline_table_close);
        rules["inline_table_sep"] = toDelegate(&inline_table_sep);
        rules["inline_table_keyvals"] = toDelegate(&inline_table_keyvals);
        rules["array_table"] = toDelegate(&array_table);
        rules["array_table_open"] = toDelegate(&array_table_open);
        rules["array_table_close"] = toDelegate(&array_table_close);
        rules["ALPHA"] = toDelegate(&ALPHA);
        rules["DIGIT"] = toDelegate(&DIGIT);
        rules["HEXDIG"] = toDelegate(&HEXDIG);
        rules["Spacing"] = toDelegate(&Spacing);
    }

    template hooked(alias r, string name)
    {
        static ParseTree hooked(ParseTree p)
        {
            ParseTree result;

            if (name in before)
            {
                result = before[name](p);
                if (result.successful)
                    return result;
            }

            result = r(p);
            if (result.successful || name !in after)
                return result;

            result = after[name](p);
            return result;
        }

        static ParseTree hooked(string input)
        {
            return hooked!(r, name)(ParseTree("",false,[],input));
        }
    }

    static void addRuleBefore(string parentRule, string ruleSyntax)
    {
        // enum name is the current grammar name
        DynamicGrammar dg = pegged.dynamic.grammar.grammar(name ~ ": " ~ ruleSyntax, rules);
        foreach(ruleName,rule; dg.rules)
            if (ruleName != "Spacing") // Keep the local Spacing rule, do not overwrite it
                rules[ruleName] = rule;
        before[parentRule] = rules[dg.startingRule];
    }

    static void addRuleAfter(string parentRule, string ruleSyntax)
    {
        // enum name is the current grammar named
        DynamicGrammar dg = pegged.dynamic.grammar.grammar(name ~ ": " ~ ruleSyntax, rules);
        foreach(ruleName,rule; dg.rules)
        {
            if (ruleName != "Spacing")
                rules[ruleName] = rule;
        }
        after[parentRule] = rules[dg.startingRule];
    }

    static bool isRule(string s)
    {
        import std.algorithm : startsWith;
        return s.startsWith("TomlGrammar.");
    }
    mixin decimateTree;

    alias spacing Spacing;

    static TParseTree toml(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(expression, pegged.peg.zeroOrMore!(pegged.peg.and!(newline, expression)), pegged.peg.discard!(eoi)), "TomlGrammar.toml")(p);
        }
        else
        {
            if (auto m = tuple(`toml`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(expression, pegged.peg.zeroOrMore!(pegged.peg.and!(newline, expression)), pegged.peg.discard!(eoi)), "TomlGrammar.toml"), "toml")(p);
                memo[tuple(`toml`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree toml(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(expression, pegged.peg.zeroOrMore!(pegged.peg.and!(newline, expression)), pegged.peg.discard!(eoi)), "TomlGrammar.toml")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(expression, pegged.peg.zeroOrMore!(pegged.peg.and!(newline, expression)), pegged.peg.discard!(eoi)), "TomlGrammar.toml"), "toml")(TParseTree("", false,[], s));
        }
    }
    static string toml(GetName g)
    {
        return "TomlGrammar.toml";
    }

    static TParseTree expression(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(pegged.peg.and!(ws, table, ws, pegged.peg.option!(comment)), pegged.peg.and!(ws, keyval, ws, pegged.peg.option!(comment)), pegged.peg.and!(ws, pegged.peg.option!(comment))), "TomlGrammar.expression")(p);
        }
        else
        {
            if (auto m = tuple(`expression`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.or!(pegged.peg.and!(ws, table, ws, pegged.peg.option!(comment)), pegged.peg.and!(ws, keyval, ws, pegged.peg.option!(comment)), pegged.peg.and!(ws, pegged.peg.option!(comment))), "TomlGrammar.expression"), "expression")(p);
                memo[tuple(`expression`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree expression(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(pegged.peg.and!(ws, table, ws, pegged.peg.option!(comment)), pegged.peg.and!(ws, keyval, ws, pegged.peg.option!(comment)), pegged.peg.and!(ws, pegged.peg.option!(comment))), "TomlGrammar.expression")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.or!(pegged.peg.and!(ws, table, ws, pegged.peg.option!(comment)), pegged.peg.and!(ws, keyval, ws, pegged.peg.option!(comment)), pegged.peg.and!(ws, pegged.peg.option!(comment))), "TomlGrammar.expression"), "expression")(TParseTree("", false,[], s));
        }
    }
    static string expression(GetName g)
    {
        return "TomlGrammar.expression";
    }

    static TParseTree ws(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.zeroOrMore!(wschar), "TomlGrammar.ws")(p);
        }
        else
        {
            if (auto m = tuple(`ws`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.zeroOrMore!(wschar), "TomlGrammar.ws"), "ws")(p);
                memo[tuple(`ws`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree ws(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.zeroOrMore!(wschar), "TomlGrammar.ws")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.zeroOrMore!(wschar), "TomlGrammar.ws"), "ws")(TParseTree("", false,[], s));
        }
    }
    static string ws(GetName g)
    {
        return "TomlGrammar.ws";
    }

    static TParseTree wschar(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(pegged.peg.literal!(" "), pegged.peg.literal!("\t")), "TomlGrammar.wschar")(p);
        }
        else
        {
            if (auto m = tuple(`wschar`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.or!(pegged.peg.literal!(" "), pegged.peg.literal!("\t")), "TomlGrammar.wschar"), "wschar")(p);
                memo[tuple(`wschar`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree wschar(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(pegged.peg.literal!(" "), pegged.peg.literal!("\t")), "TomlGrammar.wschar")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.or!(pegged.peg.literal!(" "), pegged.peg.literal!("\t")), "TomlGrammar.wschar"), "wschar")(TParseTree("", false,[], s));
        }
    }
    static string wschar(GetName g)
    {
        return "TomlGrammar.wschar";
    }

    static TParseTree newline(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.discard!(pegged.peg.or!(pegged.peg.literal!("\n"), pegged.peg.and!(pegged.peg.literal!("\r"), pegged.peg.literal!("\n")))), "TomlGrammar.newline")(p);
        }
        else
        {
            if (auto m = tuple(`newline`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.discard!(pegged.peg.or!(pegged.peg.literal!("\n"), pegged.peg.and!(pegged.peg.literal!("\r"), pegged.peg.literal!("\n")))), "TomlGrammar.newline"), "newline")(p);
                memo[tuple(`newline`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree newline(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.discard!(pegged.peg.or!(pegged.peg.literal!("\n"), pegged.peg.and!(pegged.peg.literal!("\r"), pegged.peg.literal!("\n")))), "TomlGrammar.newline")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.discard!(pegged.peg.or!(pegged.peg.literal!("\n"), pegged.peg.and!(pegged.peg.literal!("\r"), pegged.peg.literal!("\n")))), "TomlGrammar.newline"), "newline")(TParseTree("", false,[], s));
        }
    }
    static string newline(GetName g)
    {
        return "TomlGrammar.newline";
    }

    static TParseTree comment_start_symbol(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.literal!("#"), "TomlGrammar.comment_start_symbol")(p);
        }
        else
        {
            if (auto m = tuple(`comment_start_symbol`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.literal!("#"), "TomlGrammar.comment_start_symbol"), "comment_start_symbol")(p);
                memo[tuple(`comment_start_symbol`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree comment_start_symbol(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.literal!("#"), "TomlGrammar.comment_start_symbol")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.literal!("#"), "TomlGrammar.comment_start_symbol"), "comment_start_symbol")(TParseTree("", false,[], s));
        }
    }
    static string comment_start_symbol(GetName g)
    {
        return "TomlGrammar.comment_start_symbol";
    }

    static TParseTree non_ascii(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(pegged.peg.charRange!('\x80', '\uD7FF'), pegged.peg.charRange!('\uE000', '\U0010FFFF')), "TomlGrammar.non_ascii")(p);
        }
        else
        {
            if (auto m = tuple(`non_ascii`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.or!(pegged.peg.charRange!('\x80', '\uD7FF'), pegged.peg.charRange!('\uE000', '\U0010FFFF')), "TomlGrammar.non_ascii"), "non_ascii")(p);
                memo[tuple(`non_ascii`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree non_ascii(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(pegged.peg.charRange!('\x80', '\uD7FF'), pegged.peg.charRange!('\uE000', '\U0010FFFF')), "TomlGrammar.non_ascii")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.or!(pegged.peg.charRange!('\x80', '\uD7FF'), pegged.peg.charRange!('\uE000', '\U0010FFFF')), "TomlGrammar.non_ascii"), "non_ascii")(TParseTree("", false,[], s));
        }
    }
    static string non_ascii(GetName g)
    {
        return "TomlGrammar.non_ascii";
    }

    static TParseTree non_eol(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(pegged.peg.literal!("\t"), pegged.peg.charRange!(' ', '~'), non_ascii), "TomlGrammar.non_eol")(p);
        }
        else
        {
            if (auto m = tuple(`non_eol`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.or!(pegged.peg.literal!("\t"), pegged.peg.charRange!(' ', '~'), non_ascii), "TomlGrammar.non_eol"), "non_eol")(p);
                memo[tuple(`non_eol`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree non_eol(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(pegged.peg.literal!("\t"), pegged.peg.charRange!(' ', '~'), non_ascii), "TomlGrammar.non_eol")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.or!(pegged.peg.literal!("\t"), pegged.peg.charRange!(' ', '~'), non_ascii), "TomlGrammar.non_eol"), "non_eol")(TParseTree("", false,[], s));
        }
    }
    static string non_eol(GetName g)
    {
        return "TomlGrammar.non_eol";
    }

    static TParseTree comment(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(comment_start_symbol, pegged.peg.zeroOrMore!(non_eol)), "TomlGrammar.comment")(p);
        }
        else
        {
            if (auto m = tuple(`comment`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(comment_start_symbol, pegged.peg.zeroOrMore!(non_eol)), "TomlGrammar.comment"), "comment")(p);
                memo[tuple(`comment`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree comment(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(comment_start_symbol, pegged.peg.zeroOrMore!(non_eol)), "TomlGrammar.comment")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(comment_start_symbol, pegged.peg.zeroOrMore!(non_eol)), "TomlGrammar.comment"), "comment")(TParseTree("", false,[], s));
        }
    }
    static string comment(GetName g)
    {
        return "TomlGrammar.comment";
    }

    static TParseTree keyval(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(key, keyval_sep, val), "TomlGrammar.keyval")(p);
        }
        else
        {
            if (auto m = tuple(`keyval`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(key, keyval_sep, val), "TomlGrammar.keyval"), "keyval")(p);
                memo[tuple(`keyval`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree keyval(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(key, keyval_sep, val), "TomlGrammar.keyval")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(key, keyval_sep, val), "TomlGrammar.keyval"), "keyval")(TParseTree("", false,[], s));
        }
    }
    static string keyval(GetName g)
    {
        return "TomlGrammar.keyval";
    }

    static TParseTree key(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(dotted_key, simple_key), "TomlGrammar.key")(p);
        }
        else
        {
            if (auto m = tuple(`key`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.or!(dotted_key, simple_key), "TomlGrammar.key"), "key")(p);
                memo[tuple(`key`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree key(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(dotted_key, simple_key), "TomlGrammar.key")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.or!(dotted_key, simple_key), "TomlGrammar.key"), "key")(TParseTree("", false,[], s));
        }
    }
    static string key(GetName g)
    {
        return "TomlGrammar.key";
    }

    static TParseTree simple_key(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(quoted_key, unquoted_key), "TomlGrammar.simple_key")(p);
        }
        else
        {
            if (auto m = tuple(`simple_key`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.or!(quoted_key, unquoted_key), "TomlGrammar.simple_key"), "simple_key")(p);
                memo[tuple(`simple_key`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree simple_key(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(quoted_key, unquoted_key), "TomlGrammar.simple_key")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.or!(quoted_key, unquoted_key), "TomlGrammar.simple_key"), "simple_key")(TParseTree("", false,[], s));
        }
    }
    static string simple_key(GetName g)
    {
        return "TomlGrammar.simple_key";
    }

    static TParseTree unquoted_key(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.oneOrMore!(pegged.peg.or!(ALPHA, DIGIT, pegged.peg.literal!("-"), pegged.peg.literal!("_"))), "TomlGrammar.unquoted_key")(p);
        }
        else
        {
            if (auto m = tuple(`unquoted_key`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.oneOrMore!(pegged.peg.or!(ALPHA, DIGIT, pegged.peg.literal!("-"), pegged.peg.literal!("_"))), "TomlGrammar.unquoted_key"), "unquoted_key")(p);
                memo[tuple(`unquoted_key`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree unquoted_key(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.oneOrMore!(pegged.peg.or!(ALPHA, DIGIT, pegged.peg.literal!("-"), pegged.peg.literal!("_"))), "TomlGrammar.unquoted_key")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.oneOrMore!(pegged.peg.or!(ALPHA, DIGIT, pegged.peg.literal!("-"), pegged.peg.literal!("_"))), "TomlGrammar.unquoted_key"), "unquoted_key")(TParseTree("", false,[], s));
        }
    }
    static string unquoted_key(GetName g)
    {
        return "TomlGrammar.unquoted_key";
    }

    static TParseTree quoted_key(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(basic_string, literal_string), "TomlGrammar.quoted_key")(p);
        }
        else
        {
            if (auto m = tuple(`quoted_key`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.or!(basic_string, literal_string), "TomlGrammar.quoted_key"), "quoted_key")(p);
                memo[tuple(`quoted_key`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree quoted_key(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(basic_string, literal_string), "TomlGrammar.quoted_key")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.or!(basic_string, literal_string), "TomlGrammar.quoted_key"), "quoted_key")(TParseTree("", false,[], s));
        }
    }
    static string quoted_key(GetName g)
    {
        return "TomlGrammar.quoted_key";
    }

    static TParseTree dotted_key(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(simple_key, pegged.peg.oneOrMore!(pegged.peg.and!(dot_sep, simple_key))), "TomlGrammar.dotted_key")(p);
        }
        else
        {
            if (auto m = tuple(`dotted_key`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(simple_key, pegged.peg.oneOrMore!(pegged.peg.and!(dot_sep, simple_key))), "TomlGrammar.dotted_key"), "dotted_key")(p);
                memo[tuple(`dotted_key`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree dotted_key(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(simple_key, pegged.peg.oneOrMore!(pegged.peg.and!(dot_sep, simple_key))), "TomlGrammar.dotted_key")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(simple_key, pegged.peg.oneOrMore!(pegged.peg.and!(dot_sep, simple_key))), "TomlGrammar.dotted_key"), "dotted_key")(TParseTree("", false,[], s));
        }
    }
    static string dotted_key(GetName g)
    {
        return "TomlGrammar.dotted_key";
    }

    static TParseTree dot_sep(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(ws, pegged.peg.literal!("."), ws), "TomlGrammar.dot_sep")(p);
        }
        else
        {
            if (auto m = tuple(`dot_sep`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(ws, pegged.peg.literal!("."), ws), "TomlGrammar.dot_sep"), "dot_sep")(p);
                memo[tuple(`dot_sep`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree dot_sep(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(ws, pegged.peg.literal!("."), ws), "TomlGrammar.dot_sep")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(ws, pegged.peg.literal!("."), ws), "TomlGrammar.dot_sep"), "dot_sep")(TParseTree("", false,[], s));
        }
    }
    static string dot_sep(GetName g)
    {
        return "TomlGrammar.dot_sep";
    }

    static TParseTree keyval_sep(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(ws, pegged.peg.literal!("="), ws), "TomlGrammar.keyval_sep")(p);
        }
        else
        {
            if (auto m = tuple(`keyval_sep`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(ws, pegged.peg.literal!("="), ws), "TomlGrammar.keyval_sep"), "keyval_sep")(p);
                memo[tuple(`keyval_sep`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree keyval_sep(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(ws, pegged.peg.literal!("="), ws), "TomlGrammar.keyval_sep")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(ws, pegged.peg.literal!("="), ws), "TomlGrammar.keyval_sep"), "keyval_sep")(TParseTree("", false,[], s));
        }
    }
    static string keyval_sep(GetName g)
    {
        return "TomlGrammar.keyval_sep";
    }

    static TParseTree val(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(string_, boolean, array, inline_table, date_time, float_, integer), "TomlGrammar.val")(p);
        }
        else
        {
            if (auto m = tuple(`val`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.or!(string_, boolean, array, inline_table, date_time, float_, integer), "TomlGrammar.val"), "val")(p);
                memo[tuple(`val`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree val(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(string_, boolean, array, inline_table, date_time, float_, integer), "TomlGrammar.val")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.or!(string_, boolean, array, inline_table, date_time, float_, integer), "TomlGrammar.val"), "val")(TParseTree("", false,[], s));
        }
    }
    static string val(GetName g)
    {
        return "TomlGrammar.val";
    }

    static TParseTree string_(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(ml_basic_string, basic_string, ml_literal_string, literal_string), "TomlGrammar.string_")(p);
        }
        else
        {
            if (auto m = tuple(`string_`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.or!(ml_basic_string, basic_string, ml_literal_string, literal_string), "TomlGrammar.string_"), "string_")(p);
                memo[tuple(`string_`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree string_(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(ml_basic_string, basic_string, ml_literal_string, literal_string), "TomlGrammar.string_")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.or!(ml_basic_string, basic_string, ml_literal_string, literal_string), "TomlGrammar.string_"), "string_")(TParseTree("", false,[], s));
        }
    }
    static string string_(GetName g)
    {
        return "TomlGrammar.string_";
    }

    static TParseTree basic_string(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(quotation_mark, pegged.peg.zeroOrMore!(basic_char), quotation_mark), "TomlGrammar.basic_string")(p);
        }
        else
        {
            if (auto m = tuple(`basic_string`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(quotation_mark, pegged.peg.zeroOrMore!(basic_char), quotation_mark), "TomlGrammar.basic_string"), "basic_string")(p);
                memo[tuple(`basic_string`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree basic_string(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(quotation_mark, pegged.peg.zeroOrMore!(basic_char), quotation_mark), "TomlGrammar.basic_string")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(quotation_mark, pegged.peg.zeroOrMore!(basic_char), quotation_mark), "TomlGrammar.basic_string"), "basic_string")(TParseTree("", false,[], s));
        }
    }
    static string basic_string(GetName g)
    {
        return "TomlGrammar.basic_string";
    }

    static TParseTree quotation_mark(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.literal!(`"`), "TomlGrammar.quotation_mark")(p);
        }
        else
        {
            if (auto m = tuple(`quotation_mark`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.literal!(`"`), "TomlGrammar.quotation_mark"), "quotation_mark")(p);
                memo[tuple(`quotation_mark`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree quotation_mark(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.literal!(`"`), "TomlGrammar.quotation_mark")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.literal!(`"`), "TomlGrammar.quotation_mark"), "quotation_mark")(TParseTree("", false,[], s));
        }
    }
    static string quotation_mark(GetName g)
    {
        return "TomlGrammar.quotation_mark";
    }

    static TParseTree basic_char(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(basic_unescaped, escaped), "TomlGrammar.basic_char")(p);
        }
        else
        {
            if (auto m = tuple(`basic_char`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.or!(basic_unescaped, escaped), "TomlGrammar.basic_char"), "basic_char")(p);
                memo[tuple(`basic_char`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree basic_char(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(basic_unescaped, escaped), "TomlGrammar.basic_char")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.or!(basic_unescaped, escaped), "TomlGrammar.basic_char"), "basic_char")(TParseTree("", false,[], s));
        }
    }
    static string basic_char(GetName g)
    {
        return "TomlGrammar.basic_char";
    }

    static TParseTree basic_unescaped(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(wschar, pegged.peg.literal!("!"), pegged.peg.charRange!('#', '['), pegged.peg.charRange!(']', '~'), non_ascii), "TomlGrammar.basic_unescaped")(p);
        }
        else
        {
            if (auto m = tuple(`basic_unescaped`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.or!(wschar, pegged.peg.literal!("!"), pegged.peg.charRange!('#', '['), pegged.peg.charRange!(']', '~'), non_ascii), "TomlGrammar.basic_unescaped"), "basic_unescaped")(p);
                memo[tuple(`basic_unescaped`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree basic_unescaped(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(wschar, pegged.peg.literal!("!"), pegged.peg.charRange!('#', '['), pegged.peg.charRange!(']', '~'), non_ascii), "TomlGrammar.basic_unescaped")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.or!(wschar, pegged.peg.literal!("!"), pegged.peg.charRange!('#', '['), pegged.peg.charRange!(']', '~'), non_ascii), "TomlGrammar.basic_unescaped"), "basic_unescaped")(TParseTree("", false,[], s));
        }
    }
    static string basic_unescaped(GetName g)
    {
        return "TomlGrammar.basic_unescaped";
    }

    static TParseTree escaped(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(escape, escape_seq_char), "TomlGrammar.escaped")(p);
        }
        else
        {
            if (auto m = tuple(`escaped`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(escape, escape_seq_char), "TomlGrammar.escaped"), "escaped")(p);
                memo[tuple(`escaped`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree escaped(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(escape, escape_seq_char), "TomlGrammar.escaped")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(escape, escape_seq_char), "TomlGrammar.escaped"), "escaped")(TParseTree("", false,[], s));
        }
    }
    static string escaped(GetName g)
    {
        return "TomlGrammar.escaped";
    }

    static TParseTree escape(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.literal!(`\`), "TomlGrammar.escape")(p);
        }
        else
        {
            if (auto m = tuple(`escape`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.literal!(`\`), "TomlGrammar.escape"), "escape")(p);
                memo[tuple(`escape`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree escape(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.literal!(`\`), "TomlGrammar.escape")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.literal!(`\`), "TomlGrammar.escape"), "escape")(TParseTree("", false,[], s));
        }
    }
    static string escape(GetName g)
    {
        return "TomlGrammar.escape";
    }

    static TParseTree escape_seq_char(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(pegged.peg.literal!(`"`), pegged.peg.literal!(`\`), pegged.peg.literal!("b"), pegged.peg.literal!("f"), pegged.peg.literal!("n"), pegged.peg.literal!("r"), pegged.peg.literal!("t"), pegged.peg.and!(pegged.peg.literal!("u"), HEXDIG, HEXDIG, HEXDIG, HEXDIG), pegged.peg.and!(pegged.peg.literal!("U"), HEXDIG, HEXDIG, HEXDIG, HEXDIG, HEXDIG, HEXDIG, HEXDIG, HEXDIG)), "TomlGrammar.escape_seq_char")(p);
        }
        else
        {
            if (auto m = tuple(`escape_seq_char`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.or!(pegged.peg.literal!(`"`), pegged.peg.literal!(`\`), pegged.peg.literal!("b"), pegged.peg.literal!("f"), pegged.peg.literal!("n"), pegged.peg.literal!("r"), pegged.peg.literal!("t"), pegged.peg.and!(pegged.peg.literal!("u"), HEXDIG, HEXDIG, HEXDIG, HEXDIG), pegged.peg.and!(pegged.peg.literal!("U"), HEXDIG, HEXDIG, HEXDIG, HEXDIG, HEXDIG, HEXDIG, HEXDIG, HEXDIG)), "TomlGrammar.escape_seq_char"), "escape_seq_char")(p);
                memo[tuple(`escape_seq_char`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree escape_seq_char(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(pegged.peg.literal!(`"`), pegged.peg.literal!(`\`), pegged.peg.literal!("b"), pegged.peg.literal!("f"), pegged.peg.literal!("n"), pegged.peg.literal!("r"), pegged.peg.literal!("t"), pegged.peg.and!(pegged.peg.literal!("u"), HEXDIG, HEXDIG, HEXDIG, HEXDIG), pegged.peg.and!(pegged.peg.literal!("U"), HEXDIG, HEXDIG, HEXDIG, HEXDIG, HEXDIG, HEXDIG, HEXDIG, HEXDIG)), "TomlGrammar.escape_seq_char")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.or!(pegged.peg.literal!(`"`), pegged.peg.literal!(`\`), pegged.peg.literal!("b"), pegged.peg.literal!("f"), pegged.peg.literal!("n"), pegged.peg.literal!("r"), pegged.peg.literal!("t"), pegged.peg.and!(pegged.peg.literal!("u"), HEXDIG, HEXDIG, HEXDIG, HEXDIG), pegged.peg.and!(pegged.peg.literal!("U"), HEXDIG, HEXDIG, HEXDIG, HEXDIG, HEXDIG, HEXDIG, HEXDIG, HEXDIG)), "TomlGrammar.escape_seq_char"), "escape_seq_char")(TParseTree("", false,[], s));
        }
    }
    static string escape_seq_char(GetName g)
    {
        return "TomlGrammar.escape_seq_char";
    }

    static TParseTree ml_basic_string(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(ml_basic_string_delim, pegged.peg.option!(newline), ml_basic_body, ml_basic_string_delim), "TomlGrammar.ml_basic_string")(p);
        }
        else
        {
            if (auto m = tuple(`ml_basic_string`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(ml_basic_string_delim, pegged.peg.option!(newline), ml_basic_body, ml_basic_string_delim), "TomlGrammar.ml_basic_string"), "ml_basic_string")(p);
                memo[tuple(`ml_basic_string`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree ml_basic_string(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(ml_basic_string_delim, pegged.peg.option!(newline), ml_basic_body, ml_basic_string_delim), "TomlGrammar.ml_basic_string")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(ml_basic_string_delim, pegged.peg.option!(newline), ml_basic_body, ml_basic_string_delim), "TomlGrammar.ml_basic_string"), "ml_basic_string")(TParseTree("", false,[], s));
        }
    }
    static string ml_basic_string(GetName g)
    {
        return "TomlGrammar.ml_basic_string";
    }

    static TParseTree ml_basic_string_delim(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(quotation_mark, quotation_mark, quotation_mark), "TomlGrammar.ml_basic_string_delim")(p);
        }
        else
        {
            if (auto m = tuple(`ml_basic_string_delim`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(quotation_mark, quotation_mark, quotation_mark), "TomlGrammar.ml_basic_string_delim"), "ml_basic_string_delim")(p);
                memo[tuple(`ml_basic_string_delim`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree ml_basic_string_delim(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(quotation_mark, quotation_mark, quotation_mark), "TomlGrammar.ml_basic_string_delim")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(quotation_mark, quotation_mark, quotation_mark), "TomlGrammar.ml_basic_string_delim"), "ml_basic_string_delim")(TParseTree("", false,[], s));
        }
    }
    static string ml_basic_string_delim(GetName g)
    {
        return "TomlGrammar.ml_basic_string_delim";
    }

    static TParseTree ml_basic_body(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.zeroOrMore!(mlb_content), pegged.peg.zeroOrMore!(pegged.peg.and!(mlb_quotes, pegged.peg.oneOrMore!(mlb_content))), pegged.peg.option!(mlb_quotes)), "TomlGrammar.ml_basic_body")(p);
        }
        else
        {
            if (auto m = tuple(`ml_basic_body`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.zeroOrMore!(mlb_content), pegged.peg.zeroOrMore!(pegged.peg.and!(mlb_quotes, pegged.peg.oneOrMore!(mlb_content))), pegged.peg.option!(mlb_quotes)), "TomlGrammar.ml_basic_body"), "ml_basic_body")(p);
                memo[tuple(`ml_basic_body`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree ml_basic_body(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.zeroOrMore!(mlb_content), pegged.peg.zeroOrMore!(pegged.peg.and!(mlb_quotes, pegged.peg.oneOrMore!(mlb_content))), pegged.peg.option!(mlb_quotes)), "TomlGrammar.ml_basic_body")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.zeroOrMore!(mlb_content), pegged.peg.zeroOrMore!(pegged.peg.and!(mlb_quotes, pegged.peg.oneOrMore!(mlb_content))), pegged.peg.option!(mlb_quotes)), "TomlGrammar.ml_basic_body"), "ml_basic_body")(TParseTree("", false,[], s));
        }
    }
    static string ml_basic_body(GetName g)
    {
        return "TomlGrammar.ml_basic_body";
    }

    static TParseTree mlb_content(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(mlb_char, newline, mlb_escaped_nl), "TomlGrammar.mlb_content")(p);
        }
        else
        {
            if (auto m = tuple(`mlb_content`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.or!(mlb_char, newline, mlb_escaped_nl), "TomlGrammar.mlb_content"), "mlb_content")(p);
                memo[tuple(`mlb_content`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree mlb_content(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(mlb_char, newline, mlb_escaped_nl), "TomlGrammar.mlb_content")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.or!(mlb_char, newline, mlb_escaped_nl), "TomlGrammar.mlb_content"), "mlb_content")(TParseTree("", false,[], s));
        }
    }
    static string mlb_content(GetName g)
    {
        return "TomlGrammar.mlb_content";
    }

    static TParseTree mlb_char(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(mlb_unescaped, escaped), "TomlGrammar.mlb_char")(p);
        }
        else
        {
            if (auto m = tuple(`mlb_char`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.or!(mlb_unescaped, escaped), "TomlGrammar.mlb_char"), "mlb_char")(p);
                memo[tuple(`mlb_char`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree mlb_char(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(mlb_unescaped, escaped), "TomlGrammar.mlb_char")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.or!(mlb_unescaped, escaped), "TomlGrammar.mlb_char"), "mlb_char")(TParseTree("", false,[], s));
        }
    }
    static string mlb_char(GetName g)
    {
        return "TomlGrammar.mlb_char";
    }

    static TParseTree mlb_quotes(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(quotation_mark, pegged.peg.option!(quotation_mark), pegged.peg.negLookahead!(quotation_mark)), "TomlGrammar.mlb_quotes")(p);
        }
        else
        {
            if (auto m = tuple(`mlb_quotes`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(quotation_mark, pegged.peg.option!(quotation_mark), pegged.peg.negLookahead!(quotation_mark)), "TomlGrammar.mlb_quotes"), "mlb_quotes")(p);
                memo[tuple(`mlb_quotes`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree mlb_quotes(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(quotation_mark, pegged.peg.option!(quotation_mark), pegged.peg.negLookahead!(quotation_mark)), "TomlGrammar.mlb_quotes")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(quotation_mark, pegged.peg.option!(quotation_mark), pegged.peg.negLookahead!(quotation_mark)), "TomlGrammar.mlb_quotes"), "mlb_quotes")(TParseTree("", false,[], s));
        }
    }
    static string mlb_quotes(GetName g)
    {
        return "TomlGrammar.mlb_quotes";
    }

    static TParseTree mlb_unescaped(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(wschar, pegged.peg.literal!("!"), pegged.peg.charRange!('#', '['), pegged.peg.charRange!(']', '~'), non_ascii), "TomlGrammar.mlb_unescaped")(p);
        }
        else
        {
            if (auto m = tuple(`mlb_unescaped`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.or!(wschar, pegged.peg.literal!("!"), pegged.peg.charRange!('#', '['), pegged.peg.charRange!(']', '~'), non_ascii), "TomlGrammar.mlb_unescaped"), "mlb_unescaped")(p);
                memo[tuple(`mlb_unescaped`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree mlb_unescaped(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(wschar, pegged.peg.literal!("!"), pegged.peg.charRange!('#', '['), pegged.peg.charRange!(']', '~'), non_ascii), "TomlGrammar.mlb_unescaped")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.or!(wschar, pegged.peg.literal!("!"), pegged.peg.charRange!('#', '['), pegged.peg.charRange!(']', '~'), non_ascii), "TomlGrammar.mlb_unescaped"), "mlb_unescaped")(TParseTree("", false,[], s));
        }
    }
    static string mlb_unescaped(GetName g)
    {
        return "TomlGrammar.mlb_unescaped";
    }

    static TParseTree mlb_escaped_nl(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(escape, ws, newline, pegged.peg.zeroOrMore!(pegged.peg.or!(wschar, newline))), "TomlGrammar.mlb_escaped_nl")(p);
        }
        else
        {
            if (auto m = tuple(`mlb_escaped_nl`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(escape, ws, newline, pegged.peg.zeroOrMore!(pegged.peg.or!(wschar, newline))), "TomlGrammar.mlb_escaped_nl"), "mlb_escaped_nl")(p);
                memo[tuple(`mlb_escaped_nl`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree mlb_escaped_nl(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(escape, ws, newline, pegged.peg.zeroOrMore!(pegged.peg.or!(wschar, newline))), "TomlGrammar.mlb_escaped_nl")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(escape, ws, newline, pegged.peg.zeroOrMore!(pegged.peg.or!(wschar, newline))), "TomlGrammar.mlb_escaped_nl"), "mlb_escaped_nl")(TParseTree("", false,[], s));
        }
    }
    static string mlb_escaped_nl(GetName g)
    {
        return "TomlGrammar.mlb_escaped_nl";
    }

    static TParseTree literal_string(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(apostrophe, pegged.peg.zeroOrMore!(literal_char), apostrophe), "TomlGrammar.literal_string")(p);
        }
        else
        {
            if (auto m = tuple(`literal_string`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(apostrophe, pegged.peg.zeroOrMore!(literal_char), apostrophe), "TomlGrammar.literal_string"), "literal_string")(p);
                memo[tuple(`literal_string`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree literal_string(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(apostrophe, pegged.peg.zeroOrMore!(literal_char), apostrophe), "TomlGrammar.literal_string")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(apostrophe, pegged.peg.zeroOrMore!(literal_char), apostrophe), "TomlGrammar.literal_string"), "literal_string")(TParseTree("", false,[], s));
        }
    }
    static string literal_string(GetName g)
    {
        return "TomlGrammar.literal_string";
    }

    static TParseTree apostrophe(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.literal!("'"), "TomlGrammar.apostrophe")(p);
        }
        else
        {
            if (auto m = tuple(`apostrophe`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.literal!("'"), "TomlGrammar.apostrophe"), "apostrophe")(p);
                memo[tuple(`apostrophe`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree apostrophe(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.literal!("'"), "TomlGrammar.apostrophe")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.literal!("'"), "TomlGrammar.apostrophe"), "apostrophe")(TParseTree("", false,[], s));
        }
    }
    static string apostrophe(GetName g)
    {
        return "TomlGrammar.apostrophe";
    }

    static TParseTree literal_char(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(pegged.peg.literal!("\t"), pegged.peg.charRange!(' ', '&'), pegged.peg.charRange!('(', '~'), non_ascii), "TomlGrammar.literal_char")(p);
        }
        else
        {
            if (auto m = tuple(`literal_char`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.or!(pegged.peg.literal!("\t"), pegged.peg.charRange!(' ', '&'), pegged.peg.charRange!('(', '~'), non_ascii), "TomlGrammar.literal_char"), "literal_char")(p);
                memo[tuple(`literal_char`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree literal_char(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(pegged.peg.literal!("\t"), pegged.peg.charRange!(' ', '&'), pegged.peg.charRange!('(', '~'), non_ascii), "TomlGrammar.literal_char")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.or!(pegged.peg.literal!("\t"), pegged.peg.charRange!(' ', '&'), pegged.peg.charRange!('(', '~'), non_ascii), "TomlGrammar.literal_char"), "literal_char")(TParseTree("", false,[], s));
        }
    }
    static string literal_char(GetName g)
    {
        return "TomlGrammar.literal_char";
    }

    static TParseTree ml_literal_string(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(ml_literal_string_delim, pegged.peg.option!(newline), ml_literal_body, ml_literal_string_delim), "TomlGrammar.ml_literal_string")(p);
        }
        else
        {
            if (auto m = tuple(`ml_literal_string`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(ml_literal_string_delim, pegged.peg.option!(newline), ml_literal_body, ml_literal_string_delim), "TomlGrammar.ml_literal_string"), "ml_literal_string")(p);
                memo[tuple(`ml_literal_string`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree ml_literal_string(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(ml_literal_string_delim, pegged.peg.option!(newline), ml_literal_body, ml_literal_string_delim), "TomlGrammar.ml_literal_string")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(ml_literal_string_delim, pegged.peg.option!(newline), ml_literal_body, ml_literal_string_delim), "TomlGrammar.ml_literal_string"), "ml_literal_string")(TParseTree("", false,[], s));
        }
    }
    static string ml_literal_string(GetName g)
    {
        return "TomlGrammar.ml_literal_string";
    }

    static TParseTree ml_literal_string_delim(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(apostrophe, apostrophe, apostrophe), "TomlGrammar.ml_literal_string_delim")(p);
        }
        else
        {
            if (auto m = tuple(`ml_literal_string_delim`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(apostrophe, apostrophe, apostrophe), "TomlGrammar.ml_literal_string_delim"), "ml_literal_string_delim")(p);
                memo[tuple(`ml_literal_string_delim`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree ml_literal_string_delim(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(apostrophe, apostrophe, apostrophe), "TomlGrammar.ml_literal_string_delim")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(apostrophe, apostrophe, apostrophe), "TomlGrammar.ml_literal_string_delim"), "ml_literal_string_delim")(TParseTree("", false,[], s));
        }
    }
    static string ml_literal_string_delim(GetName g)
    {
        return "TomlGrammar.ml_literal_string_delim";
    }

    static TParseTree ml_literal_body(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.zeroOrMore!(mll_content), pegged.peg.zeroOrMore!(pegged.peg.and!(mll_quotes, pegged.peg.oneOrMore!(mll_content))), pegged.peg.option!(mll_quotes)), "TomlGrammar.ml_literal_body")(p);
        }
        else
        {
            if (auto m = tuple(`ml_literal_body`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.zeroOrMore!(mll_content), pegged.peg.zeroOrMore!(pegged.peg.and!(mll_quotes, pegged.peg.oneOrMore!(mll_content))), pegged.peg.option!(mll_quotes)), "TomlGrammar.ml_literal_body"), "ml_literal_body")(p);
                memo[tuple(`ml_literal_body`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree ml_literal_body(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.zeroOrMore!(mll_content), pegged.peg.zeroOrMore!(pegged.peg.and!(mll_quotes, pegged.peg.oneOrMore!(mll_content))), pegged.peg.option!(mll_quotes)), "TomlGrammar.ml_literal_body")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.zeroOrMore!(mll_content), pegged.peg.zeroOrMore!(pegged.peg.and!(mll_quotes, pegged.peg.oneOrMore!(mll_content))), pegged.peg.option!(mll_quotes)), "TomlGrammar.ml_literal_body"), "ml_literal_body")(TParseTree("", false,[], s));
        }
    }
    static string ml_literal_body(GetName g)
    {
        return "TomlGrammar.ml_literal_body";
    }

    static TParseTree mll_content(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(mll_char, newline), "TomlGrammar.mll_content")(p);
        }
        else
        {
            if (auto m = tuple(`mll_content`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.or!(mll_char, newline), "TomlGrammar.mll_content"), "mll_content")(p);
                memo[tuple(`mll_content`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree mll_content(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(mll_char, newline), "TomlGrammar.mll_content")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.or!(mll_char, newline), "TomlGrammar.mll_content"), "mll_content")(TParseTree("", false,[], s));
        }
    }
    static string mll_content(GetName g)
    {
        return "TomlGrammar.mll_content";
    }

    static TParseTree mll_char(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(pegged.peg.literal!("\t"), pegged.peg.charRange!(' ', '&'), pegged.peg.charRange!('(', '~'), non_ascii), "TomlGrammar.mll_char")(p);
        }
        else
        {
            if (auto m = tuple(`mll_char`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.or!(pegged.peg.literal!("\t"), pegged.peg.charRange!(' ', '&'), pegged.peg.charRange!('(', '~'), non_ascii), "TomlGrammar.mll_char"), "mll_char")(p);
                memo[tuple(`mll_char`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree mll_char(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(pegged.peg.literal!("\t"), pegged.peg.charRange!(' ', '&'), pegged.peg.charRange!('(', '~'), non_ascii), "TomlGrammar.mll_char")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.or!(pegged.peg.literal!("\t"), pegged.peg.charRange!(' ', '&'), pegged.peg.charRange!('(', '~'), non_ascii), "TomlGrammar.mll_char"), "mll_char")(TParseTree("", false,[], s));
        }
    }
    static string mll_char(GetName g)
    {
        return "TomlGrammar.mll_char";
    }

    static TParseTree mll_quotes(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(apostrophe, pegged.peg.option!(apostrophe), pegged.peg.negLookahead!(apostrophe)), "TomlGrammar.mll_quotes")(p);
        }
        else
        {
            if (auto m = tuple(`mll_quotes`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(apostrophe, pegged.peg.option!(apostrophe), pegged.peg.negLookahead!(apostrophe)), "TomlGrammar.mll_quotes"), "mll_quotes")(p);
                memo[tuple(`mll_quotes`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree mll_quotes(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(apostrophe, pegged.peg.option!(apostrophe), pegged.peg.negLookahead!(apostrophe)), "TomlGrammar.mll_quotes")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(apostrophe, pegged.peg.option!(apostrophe), pegged.peg.negLookahead!(apostrophe)), "TomlGrammar.mll_quotes"), "mll_quotes")(TParseTree("", false,[], s));
        }
    }
    static string mll_quotes(GetName g)
    {
        return "TomlGrammar.mll_quotes";
    }

    static TParseTree integer(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(hex_int, oct_int, bin_int, dec_int), "TomlGrammar.integer")(p);
        }
        else
        {
            if (auto m = tuple(`integer`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.or!(hex_int, oct_int, bin_int, dec_int), "TomlGrammar.integer"), "integer")(p);
                memo[tuple(`integer`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree integer(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(hex_int, oct_int, bin_int, dec_int), "TomlGrammar.integer")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.or!(hex_int, oct_int, bin_int, dec_int), "TomlGrammar.integer"), "integer")(TParseTree("", false,[], s));
        }
    }
    static string integer(GetName g)
    {
        return "TomlGrammar.integer";
    }

    static TParseTree minus(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.literal!("-"), "TomlGrammar.minus")(p);
        }
        else
        {
            if (auto m = tuple(`minus`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.literal!("-"), "TomlGrammar.minus"), "minus")(p);
                memo[tuple(`minus`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree minus(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.literal!("-"), "TomlGrammar.minus")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.literal!("-"), "TomlGrammar.minus"), "minus")(TParseTree("", false,[], s));
        }
    }
    static string minus(GetName g)
    {
        return "TomlGrammar.minus";
    }

    static TParseTree plus(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.literal!("+"), "TomlGrammar.plus")(p);
        }
        else
        {
            if (auto m = tuple(`plus`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.literal!("+"), "TomlGrammar.plus"), "plus")(p);
                memo[tuple(`plus`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree plus(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.literal!("+"), "TomlGrammar.plus")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.literal!("+"), "TomlGrammar.plus"), "plus")(TParseTree("", false,[], s));
        }
    }
    static string plus(GetName g)
    {
        return "TomlGrammar.plus";
    }

    static TParseTree underscore(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.literal!("_"), "TomlGrammar.underscore")(p);
        }
        else
        {
            if (auto m = tuple(`underscore`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.literal!("_"), "TomlGrammar.underscore"), "underscore")(p);
                memo[tuple(`underscore`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree underscore(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.literal!("_"), "TomlGrammar.underscore")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.literal!("_"), "TomlGrammar.underscore"), "underscore")(TParseTree("", false,[], s));
        }
    }
    static string underscore(GetName g)
    {
        return "TomlGrammar.underscore";
    }

    static TParseTree digit1_9(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.charRange!('1', '9'), "TomlGrammar.digit1_9")(p);
        }
        else
        {
            if (auto m = tuple(`digit1_9`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.charRange!('1', '9'), "TomlGrammar.digit1_9"), "digit1_9")(p);
                memo[tuple(`digit1_9`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree digit1_9(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.charRange!('1', '9'), "TomlGrammar.digit1_9")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.charRange!('1', '9'), "TomlGrammar.digit1_9"), "digit1_9")(TParseTree("", false,[], s));
        }
    }
    static string digit1_9(GetName g)
    {
        return "TomlGrammar.digit1_9";
    }

    static TParseTree digit0_7(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.charRange!('0', '7'), "TomlGrammar.digit0_7")(p);
        }
        else
        {
            if (auto m = tuple(`digit0_7`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.charRange!('0', '7'), "TomlGrammar.digit0_7"), "digit0_7")(p);
                memo[tuple(`digit0_7`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree digit0_7(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.charRange!('0', '7'), "TomlGrammar.digit0_7")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.charRange!('0', '7'), "TomlGrammar.digit0_7"), "digit0_7")(TParseTree("", false,[], s));
        }
    }
    static string digit0_7(GetName g)
    {
        return "TomlGrammar.digit0_7";
    }

    static TParseTree digit0_1(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.charRange!('0', '1'), "TomlGrammar.digit0_1")(p);
        }
        else
        {
            if (auto m = tuple(`digit0_1`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.charRange!('0', '1'), "TomlGrammar.digit0_1"), "digit0_1")(p);
                memo[tuple(`digit0_1`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree digit0_1(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.charRange!('0', '1'), "TomlGrammar.digit0_1")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.charRange!('0', '1'), "TomlGrammar.digit0_1"), "digit0_1")(TParseTree("", false,[], s));
        }
    }
    static string digit0_1(GetName g)
    {
        return "TomlGrammar.digit0_1";
    }

    static TParseTree hex_prefix(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.literal!("0x"), "TomlGrammar.hex_prefix")(p);
        }
        else
        {
            if (auto m = tuple(`hex_prefix`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.literal!("0x"), "TomlGrammar.hex_prefix"), "hex_prefix")(p);
                memo[tuple(`hex_prefix`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree hex_prefix(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.literal!("0x"), "TomlGrammar.hex_prefix")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.literal!("0x"), "TomlGrammar.hex_prefix"), "hex_prefix")(TParseTree("", false,[], s));
        }
    }
    static string hex_prefix(GetName g)
    {
        return "TomlGrammar.hex_prefix";
    }

    static TParseTree oct_prefix(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.literal!("0o"), "TomlGrammar.oct_prefix")(p);
        }
        else
        {
            if (auto m = tuple(`oct_prefix`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.literal!("0o"), "TomlGrammar.oct_prefix"), "oct_prefix")(p);
                memo[tuple(`oct_prefix`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree oct_prefix(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.literal!("0o"), "TomlGrammar.oct_prefix")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.literal!("0o"), "TomlGrammar.oct_prefix"), "oct_prefix")(TParseTree("", false,[], s));
        }
    }
    static string oct_prefix(GetName g)
    {
        return "TomlGrammar.oct_prefix";
    }

    static TParseTree bin_prefix(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.literal!("0b"), "TomlGrammar.bin_prefix")(p);
        }
        else
        {
            if (auto m = tuple(`bin_prefix`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.literal!("0b"), "TomlGrammar.bin_prefix"), "bin_prefix")(p);
                memo[tuple(`bin_prefix`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree bin_prefix(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.literal!("0b"), "TomlGrammar.bin_prefix")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.literal!("0b"), "TomlGrammar.bin_prefix"), "bin_prefix")(TParseTree("", false,[], s));
        }
    }
    static string bin_prefix(GetName g)
    {
        return "TomlGrammar.bin_prefix";
    }

    static TParseTree dec_int(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.option!(pegged.peg.or!(minus, plus)), unsigned_dec_int), "TomlGrammar.dec_int")(p);
        }
        else
        {
            if (auto m = tuple(`dec_int`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.option!(pegged.peg.or!(minus, plus)), unsigned_dec_int), "TomlGrammar.dec_int"), "dec_int")(p);
                memo[tuple(`dec_int`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree dec_int(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.option!(pegged.peg.or!(minus, plus)), unsigned_dec_int), "TomlGrammar.dec_int")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.option!(pegged.peg.or!(minus, plus)), unsigned_dec_int), "TomlGrammar.dec_int"), "dec_int")(TParseTree("", false,[], s));
        }
    }
    static string dec_int(GetName g)
    {
        return "TomlGrammar.dec_int";
    }

    static TParseTree unsigned_dec_int(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(pegged.peg.and!(digit1_9, pegged.peg.oneOrMore!(pegged.peg.or!(DIGIT, pegged.peg.and!(underscore, DIGIT)))), DIGIT), "TomlGrammar.unsigned_dec_int")(p);
        }
        else
        {
            if (auto m = tuple(`unsigned_dec_int`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.or!(pegged.peg.and!(digit1_9, pegged.peg.oneOrMore!(pegged.peg.or!(DIGIT, pegged.peg.and!(underscore, DIGIT)))), DIGIT), "TomlGrammar.unsigned_dec_int"), "unsigned_dec_int")(p);
                memo[tuple(`unsigned_dec_int`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree unsigned_dec_int(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(pegged.peg.and!(digit1_9, pegged.peg.oneOrMore!(pegged.peg.or!(DIGIT, pegged.peg.and!(underscore, DIGIT)))), DIGIT), "TomlGrammar.unsigned_dec_int")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.or!(pegged.peg.and!(digit1_9, pegged.peg.oneOrMore!(pegged.peg.or!(DIGIT, pegged.peg.and!(underscore, DIGIT)))), DIGIT), "TomlGrammar.unsigned_dec_int"), "unsigned_dec_int")(TParseTree("", false,[], s));
        }
    }
    static string unsigned_dec_int(GetName g)
    {
        return "TomlGrammar.unsigned_dec_int";
    }

    static TParseTree hex_int(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(hex_prefix, HEXDIG, pegged.peg.zeroOrMore!(pegged.peg.or!(HEXDIG, pegged.peg.and!(underscore, HEXDIG)))), "TomlGrammar.hex_int")(p);
        }
        else
        {
            if (auto m = tuple(`hex_int`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(hex_prefix, HEXDIG, pegged.peg.zeroOrMore!(pegged.peg.or!(HEXDIG, pegged.peg.and!(underscore, HEXDIG)))), "TomlGrammar.hex_int"), "hex_int")(p);
                memo[tuple(`hex_int`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree hex_int(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(hex_prefix, HEXDIG, pegged.peg.zeroOrMore!(pegged.peg.or!(HEXDIG, pegged.peg.and!(underscore, HEXDIG)))), "TomlGrammar.hex_int")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(hex_prefix, HEXDIG, pegged.peg.zeroOrMore!(pegged.peg.or!(HEXDIG, pegged.peg.and!(underscore, HEXDIG)))), "TomlGrammar.hex_int"), "hex_int")(TParseTree("", false,[], s));
        }
    }
    static string hex_int(GetName g)
    {
        return "TomlGrammar.hex_int";
    }

    static TParseTree oct_int(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(oct_prefix, digit0_7, pegged.peg.zeroOrMore!(pegged.peg.or!(digit0_7, pegged.peg.and!(underscore, digit0_7)))), "TomlGrammar.oct_int")(p);
        }
        else
        {
            if (auto m = tuple(`oct_int`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(oct_prefix, digit0_7, pegged.peg.zeroOrMore!(pegged.peg.or!(digit0_7, pegged.peg.and!(underscore, digit0_7)))), "TomlGrammar.oct_int"), "oct_int")(p);
                memo[tuple(`oct_int`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree oct_int(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(oct_prefix, digit0_7, pegged.peg.zeroOrMore!(pegged.peg.or!(digit0_7, pegged.peg.and!(underscore, digit0_7)))), "TomlGrammar.oct_int")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(oct_prefix, digit0_7, pegged.peg.zeroOrMore!(pegged.peg.or!(digit0_7, pegged.peg.and!(underscore, digit0_7)))), "TomlGrammar.oct_int"), "oct_int")(TParseTree("", false,[], s));
        }
    }
    static string oct_int(GetName g)
    {
        return "TomlGrammar.oct_int";
    }

    static TParseTree bin_int(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(bin_prefix, digit0_1, pegged.peg.zeroOrMore!(pegged.peg.or!(digit0_1, pegged.peg.and!(underscore, digit0_1)))), "TomlGrammar.bin_int")(p);
        }
        else
        {
            if (auto m = tuple(`bin_int`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(bin_prefix, digit0_1, pegged.peg.zeroOrMore!(pegged.peg.or!(digit0_1, pegged.peg.and!(underscore, digit0_1)))), "TomlGrammar.bin_int"), "bin_int")(p);
                memo[tuple(`bin_int`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree bin_int(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(bin_prefix, digit0_1, pegged.peg.zeroOrMore!(pegged.peg.or!(digit0_1, pegged.peg.and!(underscore, digit0_1)))), "TomlGrammar.bin_int")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(bin_prefix, digit0_1, pegged.peg.zeroOrMore!(pegged.peg.or!(digit0_1, pegged.peg.and!(underscore, digit0_1)))), "TomlGrammar.bin_int"), "bin_int")(TParseTree("", false,[], s));
        }
    }
    static string bin_int(GetName g)
    {
        return "TomlGrammar.bin_int";
    }

    static TParseTree float_(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(pegged.peg.and!(float_int_part, pegged.peg.or!(exp, pegged.peg.and!(frac, pegged.peg.option!(exp)))), special_float), "TomlGrammar.float_")(p);
        }
        else
        {
            if (auto m = tuple(`float_`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.or!(pegged.peg.and!(float_int_part, pegged.peg.or!(exp, pegged.peg.and!(frac, pegged.peg.option!(exp)))), special_float), "TomlGrammar.float_"), "float_")(p);
                memo[tuple(`float_`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree float_(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(pegged.peg.and!(float_int_part, pegged.peg.or!(exp, pegged.peg.and!(frac, pegged.peg.option!(exp)))), special_float), "TomlGrammar.float_")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.or!(pegged.peg.and!(float_int_part, pegged.peg.or!(exp, pegged.peg.and!(frac, pegged.peg.option!(exp)))), special_float), "TomlGrammar.float_"), "float_")(TParseTree("", false,[], s));
        }
    }
    static string float_(GetName g)
    {
        return "TomlGrammar.float_";
    }

    static TParseTree float_int_part(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(dec_int, "TomlGrammar.float_int_part")(p);
        }
        else
        {
            if (auto m = tuple(`float_int_part`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(dec_int, "TomlGrammar.float_int_part"), "float_int_part")(p);
                memo[tuple(`float_int_part`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree float_int_part(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(dec_int, "TomlGrammar.float_int_part")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(dec_int, "TomlGrammar.float_int_part"), "float_int_part")(TParseTree("", false,[], s));
        }
    }
    static string float_int_part(GetName g)
    {
        return "TomlGrammar.float_int_part";
    }

    static TParseTree frac(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(decimal_point, zero_prefixable_int), "TomlGrammar.frac")(p);
        }
        else
        {
            if (auto m = tuple(`frac`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(decimal_point, zero_prefixable_int), "TomlGrammar.frac"), "frac")(p);
                memo[tuple(`frac`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree frac(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(decimal_point, zero_prefixable_int), "TomlGrammar.frac")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(decimal_point, zero_prefixable_int), "TomlGrammar.frac"), "frac")(TParseTree("", false,[], s));
        }
    }
    static string frac(GetName g)
    {
        return "TomlGrammar.frac";
    }

    static TParseTree decimal_point(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.literal!("."), "TomlGrammar.decimal_point")(p);
        }
        else
        {
            if (auto m = tuple(`decimal_point`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.literal!("."), "TomlGrammar.decimal_point"), "decimal_point")(p);
                memo[tuple(`decimal_point`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree decimal_point(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.literal!("."), "TomlGrammar.decimal_point")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.literal!("."), "TomlGrammar.decimal_point"), "decimal_point")(TParseTree("", false,[], s));
        }
    }
    static string decimal_point(GetName g)
    {
        return "TomlGrammar.decimal_point";
    }

    static TParseTree zero_prefixable_int(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(DIGIT, pegged.peg.zeroOrMore!(pegged.peg.or!(DIGIT, pegged.peg.and!(underscore, DIGIT)))), "TomlGrammar.zero_prefixable_int")(p);
        }
        else
        {
            if (auto m = tuple(`zero_prefixable_int`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(DIGIT, pegged.peg.zeroOrMore!(pegged.peg.or!(DIGIT, pegged.peg.and!(underscore, DIGIT)))), "TomlGrammar.zero_prefixable_int"), "zero_prefixable_int")(p);
                memo[tuple(`zero_prefixable_int`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree zero_prefixable_int(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(DIGIT, pegged.peg.zeroOrMore!(pegged.peg.or!(DIGIT, pegged.peg.and!(underscore, DIGIT)))), "TomlGrammar.zero_prefixable_int")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(DIGIT, pegged.peg.zeroOrMore!(pegged.peg.or!(DIGIT, pegged.peg.and!(underscore, DIGIT)))), "TomlGrammar.zero_prefixable_int"), "zero_prefixable_int")(TParseTree("", false,[], s));
        }
    }
    static string zero_prefixable_int(GetName g)
    {
        return "TomlGrammar.zero_prefixable_int";
    }

    static TParseTree exp(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("e"), float_exp_part), "TomlGrammar.exp")(p);
        }
        else
        {
            if (auto m = tuple(`exp`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("e"), float_exp_part), "TomlGrammar.exp"), "exp")(p);
                memo[tuple(`exp`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree exp(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("e"), float_exp_part), "TomlGrammar.exp")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("e"), float_exp_part), "TomlGrammar.exp"), "exp")(TParseTree("", false,[], s));
        }
    }
    static string exp(GetName g)
    {
        return "TomlGrammar.exp";
    }

    static TParseTree float_exp_part(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.option!(pegged.peg.or!(minus, plus)), zero_prefixable_int), "TomlGrammar.float_exp_part")(p);
        }
        else
        {
            if (auto m = tuple(`float_exp_part`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.option!(pegged.peg.or!(minus, plus)), zero_prefixable_int), "TomlGrammar.float_exp_part"), "float_exp_part")(p);
                memo[tuple(`float_exp_part`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree float_exp_part(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.option!(pegged.peg.or!(minus, plus)), zero_prefixable_int), "TomlGrammar.float_exp_part")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.option!(pegged.peg.or!(minus, plus)), zero_prefixable_int), "TomlGrammar.float_exp_part"), "float_exp_part")(TParseTree("", false,[], s));
        }
    }
    static string float_exp_part(GetName g)
    {
        return "TomlGrammar.float_exp_part";
    }

    static TParseTree special_float(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.option!(pegged.peg.or!(minus, plus)), pegged.peg.or!(inf, nan)), "TomlGrammar.special_float")(p);
        }
        else
        {
            if (auto m = tuple(`special_float`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.option!(pegged.peg.or!(minus, plus)), pegged.peg.or!(inf, nan)), "TomlGrammar.special_float"), "special_float")(p);
                memo[tuple(`special_float`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree special_float(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.option!(pegged.peg.or!(minus, plus)), pegged.peg.or!(inf, nan)), "TomlGrammar.special_float")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.option!(pegged.peg.or!(minus, plus)), pegged.peg.or!(inf, nan)), "TomlGrammar.special_float"), "special_float")(TParseTree("", false,[], s));
        }
    }
    static string special_float(GetName g)
    {
        return "TomlGrammar.special_float";
    }

    static TParseTree inf(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.literal!("inf"), "TomlGrammar.inf")(p);
        }
        else
        {
            if (auto m = tuple(`inf`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.literal!("inf"), "TomlGrammar.inf"), "inf")(p);
                memo[tuple(`inf`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree inf(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.literal!("inf"), "TomlGrammar.inf")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.literal!("inf"), "TomlGrammar.inf"), "inf")(TParseTree("", false,[], s));
        }
    }
    static string inf(GetName g)
    {
        return "TomlGrammar.inf";
    }

    static TParseTree nan(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.literal!("nan"), "TomlGrammar.nan")(p);
        }
        else
        {
            if (auto m = tuple(`nan`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.literal!("nan"), "TomlGrammar.nan"), "nan")(p);
                memo[tuple(`nan`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree nan(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.literal!("nan"), "TomlGrammar.nan")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.literal!("nan"), "TomlGrammar.nan"), "nan")(TParseTree("", false,[], s));
        }
    }
    static string nan(GetName g)
    {
        return "TomlGrammar.nan";
    }

    static TParseTree boolean(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(true_, false_), "TomlGrammar.boolean")(p);
        }
        else
        {
            if (auto m = tuple(`boolean`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.or!(true_, false_), "TomlGrammar.boolean"), "boolean")(p);
                memo[tuple(`boolean`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree boolean(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(true_, false_), "TomlGrammar.boolean")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.or!(true_, false_), "TomlGrammar.boolean"), "boolean")(TParseTree("", false,[], s));
        }
    }
    static string boolean(GetName g)
    {
        return "TomlGrammar.boolean";
    }

    static TParseTree true_(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.literal!("true"), "TomlGrammar.true_")(p);
        }
        else
        {
            if (auto m = tuple(`true_`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.literal!("true"), "TomlGrammar.true_"), "true_")(p);
                memo[tuple(`true_`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree true_(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.literal!("true"), "TomlGrammar.true_")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.literal!("true"), "TomlGrammar.true_"), "true_")(TParseTree("", false,[], s));
        }
    }
    static string true_(GetName g)
    {
        return "TomlGrammar.true_";
    }

    static TParseTree false_(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.literal!("false"), "TomlGrammar.false_")(p);
        }
        else
        {
            if (auto m = tuple(`false_`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.literal!("false"), "TomlGrammar.false_"), "false_")(p);
                memo[tuple(`false_`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree false_(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.literal!("false"), "TomlGrammar.false_")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.literal!("false"), "TomlGrammar.false_"), "false_")(TParseTree("", false,[], s));
        }
    }
    static string false_(GetName g)
    {
        return "TomlGrammar.false_";
    }

    static TParseTree date_time(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(offset_date_time, local_date_time, local_date, local_time), "TomlGrammar.date_time")(p);
        }
        else
        {
            if (auto m = tuple(`date_time`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.or!(offset_date_time, local_date_time, local_date, local_time), "TomlGrammar.date_time"), "date_time")(p);
                memo[tuple(`date_time`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree date_time(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(offset_date_time, local_date_time, local_date, local_time), "TomlGrammar.date_time")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.or!(offset_date_time, local_date_time, local_date, local_time), "TomlGrammar.date_time"), "date_time")(TParseTree("", false,[], s));
        }
    }
    static string date_time(GetName g)
    {
        return "TomlGrammar.date_time";
    }

    static TParseTree date_fullyear(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(DIGIT, DIGIT, DIGIT, DIGIT), "TomlGrammar.date_fullyear")(p);
        }
        else
        {
            if (auto m = tuple(`date_fullyear`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(DIGIT, DIGIT, DIGIT, DIGIT), "TomlGrammar.date_fullyear"), "date_fullyear")(p);
                memo[tuple(`date_fullyear`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree date_fullyear(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(DIGIT, DIGIT, DIGIT, DIGIT), "TomlGrammar.date_fullyear")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(DIGIT, DIGIT, DIGIT, DIGIT), "TomlGrammar.date_fullyear"), "date_fullyear")(TParseTree("", false,[], s));
        }
    }
    static string date_fullyear(GetName g)
    {
        return "TomlGrammar.date_fullyear";
    }

    static TParseTree date_month(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(DIGIT, DIGIT), "TomlGrammar.date_month")(p);
        }
        else
        {
            if (auto m = tuple(`date_month`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(DIGIT, DIGIT), "TomlGrammar.date_month"), "date_month")(p);
                memo[tuple(`date_month`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree date_month(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(DIGIT, DIGIT), "TomlGrammar.date_month")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(DIGIT, DIGIT), "TomlGrammar.date_month"), "date_month")(TParseTree("", false,[], s));
        }
    }
    static string date_month(GetName g)
    {
        return "TomlGrammar.date_month";
    }

    static TParseTree date_mday(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(DIGIT, DIGIT), "TomlGrammar.date_mday")(p);
        }
        else
        {
            if (auto m = tuple(`date_mday`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(DIGIT, DIGIT), "TomlGrammar.date_mday"), "date_mday")(p);
                memo[tuple(`date_mday`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree date_mday(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(DIGIT, DIGIT), "TomlGrammar.date_mday")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(DIGIT, DIGIT), "TomlGrammar.date_mday"), "date_mday")(TParseTree("", false,[], s));
        }
    }
    static string date_mday(GetName g)
    {
        return "TomlGrammar.date_mday";
    }

    static TParseTree time_delim(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(pegged.peg.literal!("T"), pegged.peg.literal!(" ")), "TomlGrammar.time_delim")(p);
        }
        else
        {
            if (auto m = tuple(`time_delim`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.or!(pegged.peg.literal!("T"), pegged.peg.literal!(" ")), "TomlGrammar.time_delim"), "time_delim")(p);
                memo[tuple(`time_delim`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree time_delim(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(pegged.peg.literal!("T"), pegged.peg.literal!(" ")), "TomlGrammar.time_delim")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.or!(pegged.peg.literal!("T"), pegged.peg.literal!(" ")), "TomlGrammar.time_delim"), "time_delim")(TParseTree("", false,[], s));
        }
    }
    static string time_delim(GetName g)
    {
        return "TomlGrammar.time_delim";
    }

    static TParseTree time_hour(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(DIGIT, DIGIT), "TomlGrammar.time_hour")(p);
        }
        else
        {
            if (auto m = tuple(`time_hour`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(DIGIT, DIGIT), "TomlGrammar.time_hour"), "time_hour")(p);
                memo[tuple(`time_hour`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree time_hour(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(DIGIT, DIGIT), "TomlGrammar.time_hour")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(DIGIT, DIGIT), "TomlGrammar.time_hour"), "time_hour")(TParseTree("", false,[], s));
        }
    }
    static string time_hour(GetName g)
    {
        return "TomlGrammar.time_hour";
    }

    static TParseTree time_minute(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(DIGIT, DIGIT), "TomlGrammar.time_minute")(p);
        }
        else
        {
            if (auto m = tuple(`time_minute`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(DIGIT, DIGIT), "TomlGrammar.time_minute"), "time_minute")(p);
                memo[tuple(`time_minute`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree time_minute(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(DIGIT, DIGIT), "TomlGrammar.time_minute")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(DIGIT, DIGIT), "TomlGrammar.time_minute"), "time_minute")(TParseTree("", false,[], s));
        }
    }
    static string time_minute(GetName g)
    {
        return "TomlGrammar.time_minute";
    }

    static TParseTree time_second(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(DIGIT, DIGIT), "TomlGrammar.time_second")(p);
        }
        else
        {
            if (auto m = tuple(`time_second`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(DIGIT, DIGIT), "TomlGrammar.time_second"), "time_second")(p);
                memo[tuple(`time_second`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree time_second(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(DIGIT, DIGIT), "TomlGrammar.time_second")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(DIGIT, DIGIT), "TomlGrammar.time_second"), "time_second")(TParseTree("", false,[], s));
        }
    }
    static string time_second(GetName g)
    {
        return "TomlGrammar.time_second";
    }

    static TParseTree time_secfrac(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("."), pegged.peg.oneOrMore!(DIGIT)), "TomlGrammar.time_secfrac")(p);
        }
        else
        {
            if (auto m = tuple(`time_secfrac`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("."), pegged.peg.oneOrMore!(DIGIT)), "TomlGrammar.time_secfrac"), "time_secfrac")(p);
                memo[tuple(`time_secfrac`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree time_secfrac(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("."), pegged.peg.oneOrMore!(DIGIT)), "TomlGrammar.time_secfrac")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("."), pegged.peg.oneOrMore!(DIGIT)), "TomlGrammar.time_secfrac"), "time_secfrac")(TParseTree("", false,[], s));
        }
    }
    static string time_secfrac(GetName g)
    {
        return "TomlGrammar.time_secfrac";
    }

    static TParseTree time_numoffset(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.keywords!("+", "-"), time_hour, pegged.peg.literal!(":"), time_minute), "TomlGrammar.time_numoffset")(p);
        }
        else
        {
            if (auto m = tuple(`time_numoffset`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.keywords!("+", "-"), time_hour, pegged.peg.literal!(":"), time_minute), "TomlGrammar.time_numoffset"), "time_numoffset")(p);
                memo[tuple(`time_numoffset`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree time_numoffset(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.keywords!("+", "-"), time_hour, pegged.peg.literal!(":"), time_minute), "TomlGrammar.time_numoffset")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.keywords!("+", "-"), time_hour, pegged.peg.literal!(":"), time_minute), "TomlGrammar.time_numoffset"), "time_numoffset")(TParseTree("", false,[], s));
        }
    }
    static string time_numoffset(GetName g)
    {
        return "TomlGrammar.time_numoffset";
    }

    static TParseTree time_offset(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(pegged.peg.literal!("Z"), time_numoffset), "TomlGrammar.time_offset")(p);
        }
        else
        {
            if (auto m = tuple(`time_offset`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.or!(pegged.peg.literal!("Z"), time_numoffset), "TomlGrammar.time_offset"), "time_offset")(p);
                memo[tuple(`time_offset`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree time_offset(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(pegged.peg.literal!("Z"), time_numoffset), "TomlGrammar.time_offset")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.or!(pegged.peg.literal!("Z"), time_numoffset), "TomlGrammar.time_offset"), "time_offset")(TParseTree("", false,[], s));
        }
    }
    static string time_offset(GetName g)
    {
        return "TomlGrammar.time_offset";
    }

    static TParseTree partial_time(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(time_hour, pegged.peg.literal!(":"), time_minute, pegged.peg.literal!(":"), time_second, pegged.peg.option!(time_secfrac)), "TomlGrammar.partial_time")(p);
        }
        else
        {
            if (auto m = tuple(`partial_time`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(time_hour, pegged.peg.literal!(":"), time_minute, pegged.peg.literal!(":"), time_second, pegged.peg.option!(time_secfrac)), "TomlGrammar.partial_time"), "partial_time")(p);
                memo[tuple(`partial_time`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree partial_time(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(time_hour, pegged.peg.literal!(":"), time_minute, pegged.peg.literal!(":"), time_second, pegged.peg.option!(time_secfrac)), "TomlGrammar.partial_time")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(time_hour, pegged.peg.literal!(":"), time_minute, pegged.peg.literal!(":"), time_second, pegged.peg.option!(time_secfrac)), "TomlGrammar.partial_time"), "partial_time")(TParseTree("", false,[], s));
        }
    }
    static string partial_time(GetName g)
    {
        return "TomlGrammar.partial_time";
    }

    static TParseTree full_date(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(date_fullyear, pegged.peg.literal!("-"), date_month, pegged.peg.literal!("-"), date_mday), "TomlGrammar.full_date")(p);
        }
        else
        {
            if (auto m = tuple(`full_date`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(date_fullyear, pegged.peg.literal!("-"), date_month, pegged.peg.literal!("-"), date_mday), "TomlGrammar.full_date"), "full_date")(p);
                memo[tuple(`full_date`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree full_date(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(date_fullyear, pegged.peg.literal!("-"), date_month, pegged.peg.literal!("-"), date_mday), "TomlGrammar.full_date")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(date_fullyear, pegged.peg.literal!("-"), date_month, pegged.peg.literal!("-"), date_mday), "TomlGrammar.full_date"), "full_date")(TParseTree("", false,[], s));
        }
    }
    static string full_date(GetName g)
    {
        return "TomlGrammar.full_date";
    }

    static TParseTree full_time(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(partial_time, time_offset), "TomlGrammar.full_time")(p);
        }
        else
        {
            if (auto m = tuple(`full_time`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(partial_time, time_offset), "TomlGrammar.full_time"), "full_time")(p);
                memo[tuple(`full_time`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree full_time(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(partial_time, time_offset), "TomlGrammar.full_time")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(partial_time, time_offset), "TomlGrammar.full_time"), "full_time")(TParseTree("", false,[], s));
        }
    }
    static string full_time(GetName g)
    {
        return "TomlGrammar.full_time";
    }

    static TParseTree offset_date_time(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(full_date, time_delim, full_time), "TomlGrammar.offset_date_time")(p);
        }
        else
        {
            if (auto m = tuple(`offset_date_time`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(full_date, time_delim, full_time), "TomlGrammar.offset_date_time"), "offset_date_time")(p);
                memo[tuple(`offset_date_time`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree offset_date_time(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(full_date, time_delim, full_time), "TomlGrammar.offset_date_time")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(full_date, time_delim, full_time), "TomlGrammar.offset_date_time"), "offset_date_time")(TParseTree("", false,[], s));
        }
    }
    static string offset_date_time(GetName g)
    {
        return "TomlGrammar.offset_date_time";
    }

    static TParseTree local_date_time(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(full_date, time_delim, partial_time), "TomlGrammar.local_date_time")(p);
        }
        else
        {
            if (auto m = tuple(`local_date_time`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(full_date, time_delim, partial_time), "TomlGrammar.local_date_time"), "local_date_time")(p);
                memo[tuple(`local_date_time`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree local_date_time(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(full_date, time_delim, partial_time), "TomlGrammar.local_date_time")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(full_date, time_delim, partial_time), "TomlGrammar.local_date_time"), "local_date_time")(TParseTree("", false,[], s));
        }
    }
    static string local_date_time(GetName g)
    {
        return "TomlGrammar.local_date_time";
    }

    static TParseTree local_date(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(full_date, "TomlGrammar.local_date")(p);
        }
        else
        {
            if (auto m = tuple(`local_date`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(full_date, "TomlGrammar.local_date"), "local_date")(p);
                memo[tuple(`local_date`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree local_date(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(full_date, "TomlGrammar.local_date")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(full_date, "TomlGrammar.local_date"), "local_date")(TParseTree("", false,[], s));
        }
    }
    static string local_date(GetName g)
    {
        return "TomlGrammar.local_date";
    }

    static TParseTree local_time(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(partial_time, "TomlGrammar.local_time")(p);
        }
        else
        {
            if (auto m = tuple(`local_time`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(partial_time, "TomlGrammar.local_time"), "local_time")(p);
                memo[tuple(`local_time`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree local_time(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(partial_time, "TomlGrammar.local_time")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(partial_time, "TomlGrammar.local_time"), "local_time")(TParseTree("", false,[], s));
        }
    }
    static string local_time(GetName g)
    {
        return "TomlGrammar.local_time";
    }

    static TParseTree array(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(array_open, pegged.peg.option!(array_values), ws_comment_newline, array_close), "TomlGrammar.array")(p);
        }
        else
        {
            if (auto m = tuple(`array`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(array_open, pegged.peg.option!(array_values), ws_comment_newline, array_close), "TomlGrammar.array"), "array")(p);
                memo[tuple(`array`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree array(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(array_open, pegged.peg.option!(array_values), ws_comment_newline, array_close), "TomlGrammar.array")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(array_open, pegged.peg.option!(array_values), ws_comment_newline, array_close), "TomlGrammar.array"), "array")(TParseTree("", false,[], s));
        }
    }
    static string array(GetName g)
    {
        return "TomlGrammar.array";
    }

    static TParseTree array_open(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.literal!("["), "TomlGrammar.array_open")(p);
        }
        else
        {
            if (auto m = tuple(`array_open`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.literal!("["), "TomlGrammar.array_open"), "array_open")(p);
                memo[tuple(`array_open`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree array_open(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.literal!("["), "TomlGrammar.array_open")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.literal!("["), "TomlGrammar.array_open"), "array_open")(TParseTree("", false,[], s));
        }
    }
    static string array_open(GetName g)
    {
        return "TomlGrammar.array_open";
    }

    static TParseTree array_close(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.literal!("]"), "TomlGrammar.array_close")(p);
        }
        else
        {
            if (auto m = tuple(`array_close`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.literal!("]"), "TomlGrammar.array_close"), "array_close")(p);
                memo[tuple(`array_close`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree array_close(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.literal!("]"), "TomlGrammar.array_close")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.literal!("]"), "TomlGrammar.array_close"), "array_close")(TParseTree("", false,[], s));
        }
    }
    static string array_close(GetName g)
    {
        return "TomlGrammar.array_close";
    }

    static TParseTree array_values(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(pegged.peg.and!(ws_comment_newline, val, ws_comment_newline, array_sep, array_values), pegged.peg.and!(ws_comment_newline, val, ws_comment_newline, pegged.peg.option!(array_sep))), "TomlGrammar.array_values")(p);
        }
        else
        {
            if (auto m = tuple(`array_values`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.or!(pegged.peg.and!(ws_comment_newline, val, ws_comment_newline, array_sep, array_values), pegged.peg.and!(ws_comment_newline, val, ws_comment_newline, pegged.peg.option!(array_sep))), "TomlGrammar.array_values"), "array_values")(p);
                memo[tuple(`array_values`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree array_values(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(pegged.peg.and!(ws_comment_newline, val, ws_comment_newline, array_sep, array_values), pegged.peg.and!(ws_comment_newline, val, ws_comment_newline, pegged.peg.option!(array_sep))), "TomlGrammar.array_values")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.or!(pegged.peg.and!(ws_comment_newline, val, ws_comment_newline, array_sep, array_values), pegged.peg.and!(ws_comment_newline, val, ws_comment_newline, pegged.peg.option!(array_sep))), "TomlGrammar.array_values"), "array_values")(TParseTree("", false,[], s));
        }
    }
    static string array_values(GetName g)
    {
        return "TomlGrammar.array_values";
    }

    static TParseTree array_sep(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.literal!(","), "TomlGrammar.array_sep")(p);
        }
        else
        {
            if (auto m = tuple(`array_sep`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.literal!(","), "TomlGrammar.array_sep"), "array_sep")(p);
                memo[tuple(`array_sep`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree array_sep(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.literal!(","), "TomlGrammar.array_sep")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.literal!(","), "TomlGrammar.array_sep"), "array_sep")(TParseTree("", false,[], s));
        }
    }
    static string array_sep(GetName g)
    {
        return "TomlGrammar.array_sep";
    }

    static TParseTree ws_comment_newline(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.zeroOrMore!(pegged.peg.or!(wschar, pegged.peg.and!(pegged.peg.option!(comment), newline))), "TomlGrammar.ws_comment_newline")(p);
        }
        else
        {
            if (auto m = tuple(`ws_comment_newline`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.zeroOrMore!(pegged.peg.or!(wschar, pegged.peg.and!(pegged.peg.option!(comment), newline))), "TomlGrammar.ws_comment_newline"), "ws_comment_newline")(p);
                memo[tuple(`ws_comment_newline`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree ws_comment_newline(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.zeroOrMore!(pegged.peg.or!(wschar, pegged.peg.and!(pegged.peg.option!(comment), newline))), "TomlGrammar.ws_comment_newline")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.zeroOrMore!(pegged.peg.or!(wschar, pegged.peg.and!(pegged.peg.option!(comment), newline))), "TomlGrammar.ws_comment_newline"), "ws_comment_newline")(TParseTree("", false,[], s));
        }
    }
    static string ws_comment_newline(GetName g)
    {
        return "TomlGrammar.ws_comment_newline";
    }

    static TParseTree table(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(std_table, array_table), "TomlGrammar.table")(p);
        }
        else
        {
            if (auto m = tuple(`table`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.or!(std_table, array_table), "TomlGrammar.table"), "table")(p);
                memo[tuple(`table`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree table(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(std_table, array_table), "TomlGrammar.table")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.or!(std_table, array_table), "TomlGrammar.table"), "table")(TParseTree("", false,[], s));
        }
    }
    static string table(GetName g)
    {
        return "TomlGrammar.table";
    }

    static TParseTree std_table(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(std_table_open, key, std_table_close), "TomlGrammar.std_table")(p);
        }
        else
        {
            if (auto m = tuple(`std_table`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(std_table_open, key, std_table_close), "TomlGrammar.std_table"), "std_table")(p);
                memo[tuple(`std_table`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree std_table(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(std_table_open, key, std_table_close), "TomlGrammar.std_table")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(std_table_open, key, std_table_close), "TomlGrammar.std_table"), "std_table")(TParseTree("", false,[], s));
        }
    }
    static string std_table(GetName g)
    {
        return "TomlGrammar.std_table";
    }

    static TParseTree std_table_open(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("["), ws), "TomlGrammar.std_table_open")(p);
        }
        else
        {
            if (auto m = tuple(`std_table_open`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("["), ws), "TomlGrammar.std_table_open"), "std_table_open")(p);
                memo[tuple(`std_table_open`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree std_table_open(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("["), ws), "TomlGrammar.std_table_open")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("["), ws), "TomlGrammar.std_table_open"), "std_table_open")(TParseTree("", false,[], s));
        }
    }
    static string std_table_open(GetName g)
    {
        return "TomlGrammar.std_table_open";
    }

    static TParseTree std_table_close(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(ws, pegged.peg.literal!("]")), "TomlGrammar.std_table_close")(p);
        }
        else
        {
            if (auto m = tuple(`std_table_close`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(ws, pegged.peg.literal!("]")), "TomlGrammar.std_table_close"), "std_table_close")(p);
                memo[tuple(`std_table_close`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree std_table_close(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(ws, pegged.peg.literal!("]")), "TomlGrammar.std_table_close")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(ws, pegged.peg.literal!("]")), "TomlGrammar.std_table_close"), "std_table_close")(TParseTree("", false,[], s));
        }
    }
    static string std_table_close(GetName g)
    {
        return "TomlGrammar.std_table_close";
    }

    static TParseTree inline_table(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(inline_table_open, pegged.peg.option!(inline_table_keyvals), inline_table_close), "TomlGrammar.inline_table")(p);
        }
        else
        {
            if (auto m = tuple(`inline_table`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(inline_table_open, pegged.peg.option!(inline_table_keyvals), inline_table_close), "TomlGrammar.inline_table"), "inline_table")(p);
                memo[tuple(`inline_table`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree inline_table(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(inline_table_open, pegged.peg.option!(inline_table_keyvals), inline_table_close), "TomlGrammar.inline_table")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(inline_table_open, pegged.peg.option!(inline_table_keyvals), inline_table_close), "TomlGrammar.inline_table"), "inline_table")(TParseTree("", false,[], s));
        }
    }
    static string inline_table(GetName g)
    {
        return "TomlGrammar.inline_table";
    }

    static TParseTree inline_table_open(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("{"), ws), "TomlGrammar.inline_table_open")(p);
        }
        else
        {
            if (auto m = tuple(`inline_table_open`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("{"), ws), "TomlGrammar.inline_table_open"), "inline_table_open")(p);
                memo[tuple(`inline_table_open`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree inline_table_open(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("{"), ws), "TomlGrammar.inline_table_open")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("{"), ws), "TomlGrammar.inline_table_open"), "inline_table_open")(TParseTree("", false,[], s));
        }
    }
    static string inline_table_open(GetName g)
    {
        return "TomlGrammar.inline_table_open";
    }

    static TParseTree inline_table_close(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(ws, pegged.peg.literal!("}")), "TomlGrammar.inline_table_close")(p);
        }
        else
        {
            if (auto m = tuple(`inline_table_close`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(ws, pegged.peg.literal!("}")), "TomlGrammar.inline_table_close"), "inline_table_close")(p);
                memo[tuple(`inline_table_close`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree inline_table_close(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(ws, pegged.peg.literal!("}")), "TomlGrammar.inline_table_close")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(ws, pegged.peg.literal!("}")), "TomlGrammar.inline_table_close"), "inline_table_close")(TParseTree("", false,[], s));
        }
    }
    static string inline_table_close(GetName g)
    {
        return "TomlGrammar.inline_table_close";
    }

    static TParseTree inline_table_sep(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(ws, pegged.peg.literal!(","), ws), "TomlGrammar.inline_table_sep")(p);
        }
        else
        {
            if (auto m = tuple(`inline_table_sep`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(ws, pegged.peg.literal!(","), ws), "TomlGrammar.inline_table_sep"), "inline_table_sep")(p);
                memo[tuple(`inline_table_sep`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree inline_table_sep(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(ws, pegged.peg.literal!(","), ws), "TomlGrammar.inline_table_sep")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(ws, pegged.peg.literal!(","), ws), "TomlGrammar.inline_table_sep"), "inline_table_sep")(TParseTree("", false,[], s));
        }
    }
    static string inline_table_sep(GetName g)
    {
        return "TomlGrammar.inline_table_sep";
    }

    static TParseTree inline_table_keyvals(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(keyval, pegged.peg.option!(pegged.peg.and!(inline_table_sep, inline_table_keyvals))), "TomlGrammar.inline_table_keyvals")(p);
        }
        else
        {
            if (auto m = tuple(`inline_table_keyvals`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(keyval, pegged.peg.option!(pegged.peg.and!(inline_table_sep, inline_table_keyvals))), "TomlGrammar.inline_table_keyvals"), "inline_table_keyvals")(p);
                memo[tuple(`inline_table_keyvals`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree inline_table_keyvals(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(keyval, pegged.peg.option!(pegged.peg.and!(inline_table_sep, inline_table_keyvals))), "TomlGrammar.inline_table_keyvals")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(keyval, pegged.peg.option!(pegged.peg.and!(inline_table_sep, inline_table_keyvals))), "TomlGrammar.inline_table_keyvals"), "inline_table_keyvals")(TParseTree("", false,[], s));
        }
    }
    static string inline_table_keyvals(GetName g)
    {
        return "TomlGrammar.inline_table_keyvals";
    }

    static TParseTree array_table(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(array_table_open, key, array_table_close), "TomlGrammar.array_table")(p);
        }
        else
        {
            if (auto m = tuple(`array_table`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(array_table_open, key, array_table_close), "TomlGrammar.array_table"), "array_table")(p);
                memo[tuple(`array_table`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree array_table(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(array_table_open, key, array_table_close), "TomlGrammar.array_table")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(array_table_open, key, array_table_close), "TomlGrammar.array_table"), "array_table")(TParseTree("", false,[], s));
        }
    }
    static string array_table(GetName g)
    {
        return "TomlGrammar.array_table";
    }

    static TParseTree array_table_open(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("[["), ws), "TomlGrammar.array_table_open")(p);
        }
        else
        {
            if (auto m = tuple(`array_table_open`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("[["), ws), "TomlGrammar.array_table_open"), "array_table_open")(p);
                memo[tuple(`array_table_open`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree array_table_open(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("[["), ws), "TomlGrammar.array_table_open")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("[["), ws), "TomlGrammar.array_table_open"), "array_table_open")(TParseTree("", false,[], s));
        }
    }
    static string array_table_open(GetName g)
    {
        return "TomlGrammar.array_table_open";
    }

    static TParseTree array_table_close(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(ws, pegged.peg.literal!("]]")), "TomlGrammar.array_table_close")(p);
        }
        else
        {
            if (auto m = tuple(`array_table_close`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(ws, pegged.peg.literal!("]]")), "TomlGrammar.array_table_close"), "array_table_close")(p);
                memo[tuple(`array_table_close`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree array_table_close(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(ws, pegged.peg.literal!("]]")), "TomlGrammar.array_table_close")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(ws, pegged.peg.literal!("]]")), "TomlGrammar.array_table_close"), "array_table_close")(TParseTree("", false,[], s));
        }
    }
    static string array_table_close(GetName g)
    {
        return "TomlGrammar.array_table_close";
    }

    static TParseTree ALPHA(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(pegged.peg.charRange!('A', 'Z'), pegged.peg.charRange!('a', 'z')), "TomlGrammar.ALPHA")(p);
        }
        else
        {
            if (auto m = tuple(`ALPHA`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.or!(pegged.peg.charRange!('A', 'Z'), pegged.peg.charRange!('a', 'z')), "TomlGrammar.ALPHA"), "ALPHA")(p);
                memo[tuple(`ALPHA`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree ALPHA(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(pegged.peg.charRange!('A', 'Z'), pegged.peg.charRange!('a', 'z')), "TomlGrammar.ALPHA")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.or!(pegged.peg.charRange!('A', 'Z'), pegged.peg.charRange!('a', 'z')), "TomlGrammar.ALPHA"), "ALPHA")(TParseTree("", false,[], s));
        }
    }
    static string ALPHA(GetName g)
    {
        return "TomlGrammar.ALPHA";
    }

    static TParseTree DIGIT(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.charRange!('0', '9'), "TomlGrammar.DIGIT")(p);
        }
        else
        {
            if (auto m = tuple(`DIGIT`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.charRange!('0', '9'), "TomlGrammar.DIGIT"), "DIGIT")(p);
                memo[tuple(`DIGIT`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree DIGIT(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.charRange!('0', '9'), "TomlGrammar.DIGIT")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.charRange!('0', '9'), "TomlGrammar.DIGIT"), "DIGIT")(TParseTree("", false,[], s));
        }
    }
    static string DIGIT(GetName g)
    {
        return "TomlGrammar.DIGIT";
    }

    static TParseTree HEXDIG(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(DIGIT, pegged.peg.or!(pegged.peg.charRange!('A', 'F'), pegged.peg.charRange!('a', 'f'))), "TomlGrammar.HEXDIG")(p);
        }
        else
        {
            if (auto m = tuple(`HEXDIG`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.or!(DIGIT, pegged.peg.or!(pegged.peg.charRange!('A', 'F'), pegged.peg.charRange!('a', 'f'))), "TomlGrammar.HEXDIG"), "HEXDIG")(p);
                memo[tuple(`HEXDIG`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree HEXDIG(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(DIGIT, pegged.peg.or!(pegged.peg.charRange!('A', 'F'), pegged.peg.charRange!('a', 'f'))), "TomlGrammar.HEXDIG")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.or!(DIGIT, pegged.peg.or!(pegged.peg.charRange!('A', 'F'), pegged.peg.charRange!('a', 'f'))), "TomlGrammar.HEXDIG"), "HEXDIG")(TParseTree("", false,[], s));
        }
    }
    static string HEXDIG(GetName g)
    {
        return "TomlGrammar.HEXDIG";
    }

    static TParseTree opCall(TParseTree p)
    {
        TParseTree result = decimateTree(toml(p));
        result.children = [result];
        result.name = "TomlGrammar";
        return result;
    }

    static TParseTree opCall(string input)
    {
        if(__ctfe)
        {
            return TomlGrammar(TParseTree(``, false, [], input, 0, 0));
        }
        else
        {
            forgetMemo();
            return TomlGrammar(TParseTree(``, false, [], input, 0, 0));
        }
    }
    static string opCall(GetName g)
    {
        return "TomlGrammar";
    }


    static void forgetMemo()
    {
        memo = null;
    }
    }
}

alias GenericTomlGrammar!(ParseTree).TomlGrammar TomlGrammar;

