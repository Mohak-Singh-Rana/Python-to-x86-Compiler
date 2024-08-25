%{  
    /*definitions*/
    #include <bits/stdc++.h>
    #include "data.h"
    #include "symbol_table.cpp"
    // #include "functions.cpp"
    using namespace std;

    extern int yylex();
    extern int yyparse();
    extern void yyrestart(FILE* file);
    extern FILE* yyin;
    extern int yylineno;
    extern char* yytext;
    void yyerror(string str);
    extern stack<int> indent_stack;

    int instCount;
    vector<vector<string>> instructions;
    vector<int> makelist(int i);
    void backpatch(vector<int> p, int i);
    void create_ins(int type,string i,string op,string arg1,string arg2);
    vector<int> merge(vector<int> p1, vector<int> p2);
    string newTemp();
    char* str_to_ch(string s);
    int tempCount;
    fstream code_out;

    // map<string,ste> global_sym_table;
    ste* global_sym_table = new ste;   //pointer to the head(initialising entry) of the global symbol table
    ste* current_ste = global_sym_table;   //pointer to current symbol table entry (initialised to pointer of head of the global symbol table)  


    char* numtochar( int num){  
        string s="0";   
        while(num>0){
            s.push_back(num%10+'0');    
            num/=10;
        }       
        reverse(s.begin(),s.end());
        int n=s.size();
        char* c= (char*)malloc(sizeof(char)*(n+1));
        for( int i=0;i<n;i++){  
            c[i]=s[i];
        }
        c[n]='\0';
        return c;
    }
    int chartonum(char * c){
        int i=0;
        int num=0;
        while(c[i]!='\0'){
            num*=10;
            num+=c[i]-'0';
            i++;
        }
        return num;
    } 
    string chartostring(char* c){
        string s;
        int i=0;
        while(c[i]!='\0'){
            s.push_back(c[i]);
            i++;
        }
        return s;
    }
%}

%union{
    struct node *elem;
}

%start file

%type<elem> M N file snippet stmt simple_stmt small_stmt_list small_stmt expr_stmt eq_testlist_star_expr_plus flow_stmt break_stmt continue_stmt return_stmt global_stmt compound_stmt funcdef parameters typedargslist typedarg tfpdef if_stmt while_stmt for_stmt suite nts_star test or_test and_test not_test comparison comp_op expr xor_expr and_expr shift_expr arith_expr term term_choice factor factor_choice power atom_expr atom STRING_PLUS trailer classdef arglist argument_list argument testlist testlist_list comma_name_star and_test_star not_test_star func_body_suite stmt_plus
%type<elem> A C X 
%token<elem> RANGE NEWLINE INDENT DEDENT ASSIGN_OPERATOR POWER_OPERATOR SHIFT_OPER FLOOR_DIV_OPER ARROW_OPER TYPE_HINT NAME IF ELSE ELIF WHILE FOR IN AND OR NOT BREAK CONTINUE RETURN CLASS DEF GLOBAL ATOM_KEYWORDS STRING NUMBER OPEN_BRACKET CLOSE_BRACKET EQUAL SEMI_COLON COLON COMMA PLUS MINUS MULTIPLY DIVIDE REMAINDER ATTHERATE NEGATION BIT_AND BIT_OR BIT_XOR DOT CURLY_OPEN CURLY_CLOSE SQUARE_OPEN SQUARE_CLOSE LESS_THAN GREATER_THAN EQUAL_EQUAL GREATER_THAN_EQUAL LESS_THAN_EQUAL NOT_EQUAL_ARROW NOT_EQUAL IS


%%


M: %empty{
        $$ = create_node(1, "Marker Non-terminal M");
        $$->ins = instCount+1;
}
;

N: %empty{
        $$ = create_node(1, "Marker Non-terminal N");
        $$->nextlist = makelist(instCount+1);
        create_ins(0, "goto", "", "", "");
}
;

file: snippet {
                $$ = $1;
            }
            ;

snippet: NEWLINE {
       $$=$1;
	   $$->ins = instCount+1;
    }
    | stmt  { 
        $$=$1;
    }
    | NEWLINE snippet  { 
        $$=$2;
    }
    | stmt snippet {  
        $$ = create_node(3, "snippet", $1, $2);
        $$->ins = $1->ins;
    }
    ; 

funcdef: DEF A parameters COLON func_body_suite {
            current_ste = get_prev_scope(current_ste);
            populate_new_scope(current_ste, "FUNCTION", $2->addr, $4->num_params, $1->lineno, 1);
        }
        | DEF A parameters ARROW_OPER C COLON func_body_suite {
            current_ste = get_prev_scope(current_ste);
            populate_new_scope(current_ste, "FUNCTION", $2->addr, $4->num_params, $1->lineno, 1);
        }
        | DEF A OPEN_BRACKET CLOSE_BRACKET COLON func_body_suite {
            current_ste = get_prev_scope(current_ste);
            populate_new_scope(current_ste, "FUNCTION", $2->addr, 0, $1->lineno, 1);
        }
        | DEF A OPEN_BRACKET CLOSE_BRACKET ARROW_OPER C COLON func_body_suite{
            current_ste = get_prev_scope(current_ste);
            populate_new_scope(current_ste, "FUNCTION", $2->addr, 0, $1->lineno, 1);
        }
    ;

A: NAME 
    {   
        $$=$1;
        //STE code start
        ste* lookup_ste = current_ste;
        if(lookup(lookup_ste, $1->addr) == NULL){
            current_ste = insert_entry_new_scope(current_ste);
        }
        else{
            cerr<<"Error: Function "<<$1->addr<<" already declared\n";
            exit(1);
        }
        //STE code end
    };

C: TYPE_HINT{
        $$=$1;
        get_prev_scope(current_ste)->return_type = $1->addr;
    }
    ;

parameters: OPEN_BRACKET typedargslist CLOSE_BRACKET {  
            $$ = create_node(4, "parameters", $1, $2, $3);
            $$->ins = $2->ins;
            $$->num_params = $2->num_params;
        }
        ;

typedargslist:  typedarg    {  
            $$=$1;
            $$->num_params=1;
        }
        | typedargslist COMMA  typedarg  {  
            $$ = create_node(4, "typedargslist", $1, $2, $3);
            $$->ins = $1->ins;

            $$->num_params = $1->num_params + 1;
        }
        ;

typedarg: tfpdef   {  
            $$=$1;
        }
        | tfpdef EQUAL test {  
            $$ = create_node(4, "typedarg", $1, $2, $3);
            $$->ins = $1->ins;
            create_ins(0, $1->addr, $2->addr, $3->addr, "");    //is this instruction needed?????
        }
        ;

tfpdef: NAME {  
            $$=$1;
			$$->ins = instCount+1;
        }
        | NAME COLON TYPE_HINT {  
            $$ = create_node(4, "tfpdef", $1, $2, $3); 
			$$->ins = instCount+1;

            //STE code start
            ste* lookup_ste = current_ste;
            if(lookup(lookup_ste, $1->addr) == NULL){
                current_ste = insert_entry_same_scope(current_ste, "VARIABLE", $1->addr, $3->addr, $1->lineno, 1);
            }
            else{
                cerr<<"Error: Variable "<<$1->addr<<" already declared\n";
                exit(1);
            }
            //STE code end

        }
        ;

stmt: simple_stmt       { 
        	$$=$1;
        }
        | compound_stmt     { 
            $$=$1; 
        }
        ;

simple_stmt: small_stmt_list SEMI_COLON NEWLINE {  
            $$=$1;
        }
        | small_stmt_list  NEWLINE {  
            $$=$1;
        }
        ; 

small_stmt_list: small_stmt     {   
            $$=$1;
        }
        | small_stmt_list SEMI_COLON small_stmt      {  
           $$ = create_node(3, "small_stmt_list", $1, $2, $3);
		   $$->ins = $1->ins;
        }
        ;

small_stmt: expr_stmt       {  
           $$=$1;
        }
        | flow_stmt     {  
           $$=$1;
        }
        | global_stmt       {  
            $$=$1;
        }
        ;

//I removed annassign
expr_stmt: 
        /* test COLON TYPE_HINT {    //list of test COLON test???
            $$ = create_node(4, "expr_stmt", $1, $2, $3);
            $$->ins = $1->ins;
        }
		| test COLON TYPE_HINT EQUAL test{
            $$ = create_node(6, "expr_stmt", $1, $2, $3, $4, $5);
            $$->ins = $1->ins;
            create_ins(0, $1->addr, $4->addr, $5->addr, "");
		} */
        test ASSIGN_OPERATOR test { 
            $$ = create_node(4, "expr_stmt", $1, $2, $3);
            $$->ins = $1->ins;
            // Here add instruction 
        }
        | test COLON TYPE_HINT ASSIGN_OPERATOR test { 
            $$ = create_node(4, "expr_stmt", $1, $2, $3);
            $$->ins = $1->ins;
            // Here add instruction 

            //STE code start
            ste* lookup_ste = current_ste;
            if(lookup(lookup_ste, $1->addr) == NULL){
                current_ste = insert_entry_same_scope(current_ste, "VARIABLE", $1->addr, $3->addr, $1->lineno, 1);
            }
            else{
                cerr<<"Error: Variable "<<$1->addr<<" already declared\n";
                exit(1);
            }
            //STE code end

        }
        | testlist {
			$$=$1;
        }
        | test EQUAL eq_testlist_star_expr_plus{
            $$ = create_node(4, "eq_testlist_star_expr_plus", $1, $2, $3);
			$$->ins = $1->ins;
			create_ins(0, $1->addr, $2->addr, $3->addr, ""); 
        }
        | test COLON TYPE_HINT EQUAL eq_testlist_star_expr_plus{
            $$ = create_node(4, "eq_testlist_star_expr_plus", $1, $2, $3);
			$$->ins = $1->ins;
			create_ins(0, $1->addr, $4->addr, $5->addr, ""); 
            //STE code start
            ste* lookup_ste = current_ste;
            if(lookup(lookup_ste, $1->addr) == NULL){
                current_ste = insert_entry_same_scope(current_ste, "VARIABLE", $1->addr, $3->addr, $1->lineno, 1);
            }
            else{
                cerr<<"Error: Variable "<<$1->addr<<" already declared\n";
                exit(1);
            }
            //STE code end
        }
    ;

/* expr_stmt: 
            /* test COLON TYPE_HINT {    //list of test COLON test???
            $$ = create_node(4, "expr_stmt", $1, $2, $3);
            $$->ins = $1->ins;
        } */
		/* | test COLON TYPE_HINT EQUAL test{
            $$ = create_node(6, "expr_stmt", $1, $2, $3, $4, $5);
            $$->ins = $1->ins;
            create_ins(0, $1->addr, $4->addr, $5->addr, "");
		} | 
         test ASSIGN_OPERATOR test { 
            $$ = create_node(4, "expr_stmt", $1, $2, $3);
            $$->ins = $1->ins;
            // Here add instruction 
        }
        | testlist {
			$$=$1;
        }
        | test EQUAL eq_testlist_star_expr_plus{
            $$ = create_node(4, "eq_testlist_star_expr_plus", $1, $2, $3);
			$$->ins = $1->ins;
			create_ins(0, $1->addr, $2->addr, $3->addr, ""); 
        }
        ; */

eq_testlist_star_expr_plus: test {
            $$=$1;
        }
        | test EQUAL eq_testlist_star_expr_plus{
            $$ = create_node(4, "eq_testlist_star_expr_plus", $1, $2, $3);
            $$->ins = $1->ins;
            create_ins(0, $1->addr, $2->addr, $3->addr, "");
            $$->addr = $1->addr;    //x=y=z
        }
        ;

flow_stmt: break_stmt   {  
            $$=$1;
        }
        | continue_stmt     {  
            $$=$1;
        }
        | return_stmt    {  
            $$=$1;
        }
        ;

break_stmt: BREAK   {  
            
            
        }
        ;
continue_stmt: CONTINUE     {  
            
        }
        ;
return_stmt: RETURN     {  
            
        }
        | RETURN test     {  
            
        } 
        ;   

global_stmt:GLOBAL NAME    {  
            $$ = create_node(3, "global_stmt", $1, $2);
            $$->ins = instCount+1;
        }
        | GLOBAL NAME comma_name_star {   
            $$ = create_node(4, "global_stmt", $1, $2, $3);
            $$->ins = $3->ins;
        }
        ;

comma_name_star: COMMA NAME    {  
            $$ = create_node(3, "comma_name_star", $1, $2);
            $$->ins = instCount+1;
        }
        | COMMA NAME comma_name_star    {  
            $$ = create_node(4, "comma_name_star", $1, $2, $3);
            $$->ins = $3->ins;
        }
        ;
compound_stmt: if_stmt      { 
            $$=$1;  
        }
        | while_stmt   {  
            $$=$1;
        }
        | for_stmt     {  
            $$=$1;
        }
        | funcdef      {  
            $$=$1;
        }
        | classdef     {  
           $$=$1;
        }
        ;  

if_stmt: IF test COLON M suite     {  
           $$=create_node(6, "if_stmt", $1, $2, $3, $4, $5);
           $$->ins = $2->ins;
           backpatch($2->truelist, $4->ins);
           $$->nextlist = merge($2->falselist, $5->nextlist);
        }
        | IF test COLON M suite N ELSE COLON M suite   {  
            $$ = create_node(11, "if_else_stmt", $1, $2, $3, $4, $5, $6, $7, $8, $9, $10);
            backpatch($2->truelist, $4->ins);
            backpatch($2->falselist, $9->ins);
            vector<int> temp = merge($5->nextlist, $6->nextlist);
            $$->nextlist = merge(temp, $10->nextlist);
        }
        | IF test COLON M suite N nts_star    {  
            $$ = create_node(8, "if_elif_stmt", $1, $2, $3, $4, $5, $6, $7);
            backpatch($2->truelist, $4->ins);
            backpatch($2->falselist, $7->ins);     
            vector<int> temp = merge($5->nextlist, $6->nextlist);
            $$->nextlist = merge(temp, $7->nextlist);
        }
        ;
while_stmt: WHILE M test COLON M suite   {  
            $$ = create_node(7, "while_stmt", $1, $2, $3, $4, $5, $6);
            $$->ins = $2->ins;
            backpatch($6->nextlist, $2->ins);
            backpatch($3->truelist, $5->ins);
            $$->nextlist = $3->falselist;
            create_ins(0, "goto", to_string($2->ins), "", "");
        }
		| WHILE M test COLON M suite N ELSE COLON M suite  {   
			$$ = create_node(12, "while_else_stmt", $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11);
			$$->ins = $2->ins;
			backpatch($7->nextlist, $2->ins);
			backpatch($6->nextlist, $2->ins);
			backpatch($3->truelist, $5->ins);
			backpatch($3->falselist, $10->ins);
			$$->nextlist = merge($7->nextlist, $11->nextlist); //verify
        }
        ;
for_stmt: FOR expr IN range_stmt COLON suite    { 
            // $$ = create_node(7, "for_stmt", $1, $2, $3, $4, $5, $6);
            // $$->ins = $2->ins;

        }
        | FOR expr IN range_stmt COLON suite ELSE COLON suite   { 
            
        }
        ;

range_stmt: RANGE OPEN_BRACKET test CLOSE_BRACKET 
        | RANGE OPEN_BRACKET test COMMA test CLOSE_BRACKET 
        ;

suite: simple_stmt  {
            $$=$1;
        }
        | NEWLINE INDENT stmt_plus DEDENT   {
            $$=$3;
        }
        | NEWLINE INDENT stmt_plus NEWLINE DEDENT   { 
            $$=$3;
        }
        ;

nts_star : ELIF test COLON M suite  {  
            $$=create_node(6, "elif_stmt", $1, $2, $3, $4, $5);
            $$->ins = $2->ins;
            backpatch($2->truelist, $4->ins);
            $$->nextlist = merge($2->falselist, $5->nextlist);
        }
        | ELIF test COLON M suite N nts_star  {  
            $$ = create_node(8, "elif_stmt", $1, $2, $3, $4, $5, $6, $7);
            $$->ins = $2->ins;
            backpatch($2->truelist, $4->ins);
            backpatch($2->falselist, $7->ins);
            $$->nextlist = merge($5->nextlist, merge($6->nextlist, $7->nextlist));
        }
        | ELIF test COLON M suite N ELSE COLON M suite  {  
            $$ = create_node(11, "elif_else_stmt", $1, $2, $3, $4, $5, $6, $7, $8, $9, $10);
            $$->ins = $2->ins;
            backpatch($2->truelist, $4->ins);
            backpatch($2->falselist, $9->ins);
            $$->nextlist = merge($5->nextlist, merge($6->nextlist,$10->nextlist));
        }
        ;

test: or_test   { 
            $$=$1;
        }
        ;

//Add support for while(a or b) types, this may be done using types
or_test: and_test    { 
            $$=$1;
        }
        | and_test_star OR M and_test    {  
            $$ = create_node(5, "or_test", $1, $2, $3, $4);
            $$->ins = $1->ins;
            backpatch($1->falselist, $3->ins);
            $$->truelist = merge($1->truelist, $4->truelist);
            $$->falselist = $4->falselist;
        }
        ;
and_test_star : and_test_star OR M and_test {
            $$ = create_node(5, "and_test_star", $1, $2, $3, $4);
            $$->ins = $1->ins;
            backpatch($1->falselist, $3->ins);
            $$->truelist = merge($1->truelist, $4->truelist);
            $$->falselist = $4->falselist;
        }
        | and_test   { 
            $$=$1;
        }
        ;

and_test: not_test  {
            $$=$1;
        }
        | not_test_star AND M not_test    {  
            $$ = create_node(5, "and_test", $1, $2, $3, $4);
            $$->ins = $1->ins;
            backpatch($1->truelist, $3->ins);
            $$->falselist = merge($1->falselist, $4->falselist);
            $$->truelist = $4->truelist;
        }
        ;
not_test_star : not_test_star AND M not_test  { 
            $$ = create_node(5, "not_test_star", $1, $2, $3, $4);
            $$->ins = $1->ins;
            backpatch($1->truelist, $3->ins);
            $$->falselist = merge($1->falselist, $4->falselist);
            $$->truelist = $4->truelist;
        }
        | not_test   { 
            $$=$1;
        }
        ;

not_test: NOT not_test   { 
            $$ = create_node(3, "not_test", $1, $2);
            $$->ins = $2->ins;
            $$->truelist = $2->falselist;
            $$->falselist = $2->truelist;
        }
        | comparison    { 
            $$=$1;
        }
;

comparison: expr  {
            $$=$1;
        }
        | expr comp_op comparison  { 
            $$=create_node(4, "comparison", $1, $2, $3);
            $$->ins = $1->ins;
            $$->addr = str_to_ch(newTemp());
            create_ins(1, $$->addr, $2->addr, $1->addr, $3->addr);
            $$->truelist = makelist(instCount+1);
            $$->falselist = makelist(instCount+2);
            create_ins(0, "if", $$->addr, "goto", "");
            create_ins(0, "goto", "", "", "");
        }
;

comp_op: LESS_THAN  {
        $$ = $1;
    }
    | GREATER_THAN  { 
       $$ = $1;
    }
    | EQUAL_EQUAL   { 
        $$ = $1;
    }
    | GREATER_THAN_EQUAL    { 
        $$ = $1;
    }
    | LESS_THAN_EQUAL   {
        $$ = $1;
    }
    | NOT_EQUAL_ARROW   {
        $$ = $1;
    }
    | NOT_EQUAL    {
       $$ = $1;
    }
    | IN    {  
        $$ = $1;
    }
    | NOT IN    { 
        $$ = create_node(3, "NOT IN", $1, $2);
    }
    | IS    { 
        $$ = $1;
    }
    | IS NOT    { 
        $$ = create_node(3, "IS NOT", $1, $2);
    }
    ;

expr: xor_expr    { 
            $$=$1;
        }
        | xor_expr BIT_OR expr    {  
            $$ = create_node(4, "expr", $1, $2, $3);
            $$->ins = $1->ins;
            $$->addr = str_to_ch(newTemp());
            create_ins(1, $$->addr, $2->addr, $1->addr, $3->addr);
        }
        ;

xor_expr: and_expr { 
            $$ = $1;
        }
        | and_expr BIT_XOR xor_expr    {  
            $$ = create_node(4, "xor_expr", $1, $2, $3);
            $$->ins = $1->ins;
            $$->addr = str_to_ch(newTemp());
            create_ins(1, $$->addr, $2->addr, $1->addr, $3->addr);
        }
        ;

and_expr: shift_expr   { 
            $$ = $1;
            
        }
        | shift_expr BIT_AND and_expr   {  
            $$ = create_node(4, "and_expr", $1, $2, $3);
            $$->ins = $1->ins;
            $$->addr = str_to_ch(newTemp());
            create_ins(1, $$->addr, $2->addr, $1->addr, $3->addr);
        }
        ;

shift_expr: arith_expr   { 
                $$ = $1; 
            }
            | arith_expr SHIFT_OPER shift_expr   { 
                $$ = create_node(4, "shift_expr", $1, $2, $3);
                $$->ins = $1->ins;
                $$->addr = str_to_ch(newTemp());
                create_ins(1, $$->addr, $2->addr, $1->addr, $3->addr);
            }
        ;

arith_expr: term { 
                $$ = $1;
            }
            | arith_expr PLUS term { 
                $$ = create_node(4, "arith_expr", $1, $2, $3);
                $$->ins = $1->ins;
                $$->addr = str_to_ch(newTemp());
                create_ins(1, $$->addr, $2->addr, $1->addr, $3->addr);
            }
            | arith_expr MINUS term { 
                $$ = create_node(4, "arith_expr", $1, $2, $3);
                $$->ins = $1->ins;
                $$->addr = str_to_ch(newTemp());
                create_ins(1, $$->addr, $2->addr, $1->addr, $3->addr);
            }
        ;
term: factor {
            $$ = $1; 
        }
        | term term_choice factor {
            $$ = create_node(4, "term", $1, $2, $3);
            $$->ins = $1->ins;
            $$->addr = str_to_ch(newTemp());
            create_ins(1, $$->addr, $2->addr, $1->addr, $3->addr);
        
		}
        ;

term_choice : MULTIPLY      { 
            $$ = $1;
        }
        |ATTHERATE      { 
            $$ = $1;
        }
        |DIVIDE         { 
            $$ = $1;
        }
        |REMAINDER      { 
            $$ = $1;
        }
        |FLOOR_DIV_OPER    { 
            $$ = $1;
        }
        ;

factor: factor_choice factor        {  
            $$ = create_node(3, "factor", $1, $2);
            $$->ins = $1->ins;
            $$->addr = str_to_ch(newTemp());
            create_ins(1, $$->addr, $1->addr,"", $2->addr);
        }
        | power     { 
            $$ = $1;
        }
        ;
factor_choice : PLUS        {
            $$=$1;
        }
        | MINUS      { 
            $$=$1;
        }
        | NEGATION   { 
            $$=$1;
        }
        ;
power: atom_expr        { 
            $$ = $1;
        }
        | atom_expr POWER_OPERATOR factor   { 
            $$ = create_node(4, "power", $1, $2, $3);
            $$->ins = $1->ins;
            $$->addr = str_to_ch(newTemp());
            create_ins(1, $$->addr, $2->addr, $1->addr, $3->addr);
        }
        ;

atom_expr: atom {  
            $$ = $1;
        }
        | atom_expr trailer {  
            $$ = create_node(3, "atom_expr", $1, $2);
            $$->ins = $1->ins;
        }
        | atom_expr DOT NAME { 
            $$ = create_node(4, "atom_expr", $1, $2, $3);
            $$->ins = $1->ins;
        }
        ;

atom: OPEN_BRACKET testlist CLOSE_BRACKET  { 
        $$=$2;
    }
    | OPEN_BRACKET CLOSE_BRACKET    {
        $$ = create_node(3, "atom", $1, $2);
        $$->ins = instCount+1;
    }
    | SQUARE_OPEN testlist SQUARE_CLOSE    { 
        $$ = $2;
    }
    | SQUARE_OPEN SQUARE_CLOSE  {
        $$ = create_node(3, "atom", $1, $2);
        $$->ins = instCount+1;
    }
    | CURLY_OPEN CURLY_CLOSE    { 
        $$ = create_node(3, "atom", $1, $2);
        $$->ins = instCount+1;
    }
    | NAME      {
        $$ = $1;
        $$->ins = instCount+1;
     }
    /* | NAME COLON TYPE_HINT  { 
        $$ = create_node(4, "atom", $1, $2, $3);
        $$->ins = instCount+1;

        //STE code start
        ste* lookup_ste = current_ste;
        if(lookup(lookup_ste, $1->addr) == NULL){
            current_ste = insert_entry_same_scope(current_ste, "VARIABLE", $1->addr, $3->addr, $1->lineno, 1);
        }
        else{
            cerr<<"Error: Variable "<<$1->addr<<" already declared\n";
            exit(1);
        }
        //STE code end

    } */
    | NUMBER        { 
        $$ = $1;
        $$->ins = instCount+1;
    }
    | STRING_PLUS       { 
       $$ = $1;
    }
    | ATOM_KEYWORDS     { 
        $$ = $1;
        $$->ins = instCount+1;
    }
    /* | TYPE_HINT     { 
        $$ = $1;
        $$->ins = instCount+1;
    } */
    ;
STRING_PLUS: STRING     {
            $$ = $1;
			$$->ins = instCount+1;
        }
        | STRING STRING_PLUS    { 
            $$ = create_node(3, "STRING_PLUS", $1, $2);
            $$->ins = $2->ins;
        }
        ;

trailer: OPEN_BRACKET CLOSE_BRACKET  { 
            $$ = create_node(3, "trailer", $1, $2);
            $$->ins = instCount+1;
        }
        | OPEN_BRACKET arglist CLOSE_BRACKET  {
            $$ = create_node(4, "trailer", $1, $2, $3);
            $$->ins = $2->ins;
        }
        | SQUARE_OPEN test SQUARE_CLOSE{
            $$ = create_node(4, "trailer", $1, $2, $3);
            $$->ins = $2->ins;
        }
        ;

testlist: testlist_list    { 
            $$ = $1;
        }
        | testlist_list COMMA   {
            $$=create_node(3,"testlist",$1,$2);
            $$->ins = $1 -> ins;
        }
        ;
testlist_list: test         {
            $$ = $1;
        }
        | test COLON TYPE_HINT{
            $$ = create_node(4, "testlist_list", $1, $2, $3);
            $$->ins = $1->ins;

            //STE code start
            ste* lookup_ste = current_ste;
            if(lookup(lookup_ste, $1->addr) == NULL){
                current_ste = insert_entry_same_scope(current_ste, "VARIABLE", $1->addr, $3->addr, $1->lineno, 1);
            }
            else{
                cerr<<"Error: Variable "<<$1->addr<<" already declared\n";
                exit(1);
            }
            //STE code end

        }
        | testlist_list COMMA test  { 
            $$ = create_node(4, "testlist_list", $1, $2, $3);
            $$->ins = $1->ins;
        }
        | testlist_list COMMA test COLON TYPE_HINT { 
            $$ = create_node(6, "testlist_list", $1, $2, $3, $4, $5);
            $$->ins = $1->ins;

            //STE code start
            ste* lookup_ste = current_ste;
            if(lookup(lookup_ste, $3->addr) == NULL){
                current_ste = insert_entry_same_scope(current_ste, "VARIABLE", $3->addr, $5->addr, $3->lineno, 1);
            }
            else{
                cerr<<"Error: Variable "<<$3->addr<<" already declared\n";
                exit(1);
            }
            //STE code end
        }
        ;   

classdef: CLASS X COLON suite      { 
            current_ste = get_prev_scope(current_ste);
            populate_new_scope(current_ste, "CLASS", $2->addr, 0, $1->lineno, 1);
        }
        | CLASS X OPEN_BRACKET CLOSE_BRACKET COLON suite      { 
            current_ste = get_prev_scope(current_ste);
            populate_new_scope(current_ste, "CLASS", $2->addr, 0, $1->lineno, 1);
        }
        | CLASS X OPEN_BRACKET arglist CLOSE_BRACKET COLON suite      { 
           current_ste = get_prev_scope(current_ste);
            populate_new_scope(current_ste, "CLASS", $2->addr, $4->num_params, $1->lineno, 1);
        }
        ;

X: NAME {
        $$=$1;
        //STE code start
        ste* lookup_ste = current_ste;
        if(lookup(lookup_ste, $1->addr) == NULL){
            current_ste = insert_entry_new_scope(current_ste);
        }
        else{
            cerr<<"Error: Class "<<$1->addr<<" already declared\n";
            exit(1);
        }
        //STE code end
};



arglist: argument_list     { 
            $$=$1;
        }
        | argument_list COMMA    { 
            $$=$1;
        }
        ;
argument_list: argument     { 
            $$=$1;
            $$->num_params=1;
        }
        | argument_list COMMA argument  { 
            $$ = create_node(4, "argument_list", $1, $2, $3);
            $$->ins = $1->ins;
            $$->num_params = $1->num_params + 1;
        }
        ;

argument: test  {
            $$=$1;
        }
        | test EQUAL test   { 
            $$ = create_node(4, "argument", $1, $2, $3);
            $$->ins = $1->ins;
            create_ins(0, $1->addr, $2->addr, $3->addr, "");
        }
        ;

func_body_suite: simple_stmt    { 
            $$ = $1;
        }
        | NEWLINE INDENT stmt_plus DEDENT   { 
            $$ = $3;
        }
        | NEWLINE INDENT stmt_plus NEWLINE DEDENT   { 
            $$ = $3;
        }
        ;

stmt_plus: stmt     {
            $$=$1;
        }
        | stmt stmt_plus    { 
            $$=create_node(3,"stmt_plus",$1,$2);
			$$->ins = $1 -> ins;
        }

%%

void yyerror(string str){
    fprintf(stderr, "Error: %s at line number %d offending token: %s\n", str.c_str(), yylineno, yytext);
    exit(1);
}

char* str_to_ch(string s)
{
	char* result_chr = new char[s.size()+1];
	strcpy(result_chr,s.c_str());
	return result_chr;
}

vector<int> makelist(int i){
	return vector<int>{i};
}

void create_ins(int type,string i,string op,string arg1,string arg2){
	vector<string> instruction{to_string(type),i,op,arg1,arg2};
	instructions.push_back(instruction);
	instCount++;
}

void backpatch(vector<int>p, int i){
	for(int j=0;j<p.size();j++)
		instructions[p[j]-1].push_back(to_string(i));
}

vector<int> merge(vector<int> p1, vector<int> p2){
        vector<int> merged;
        merged.reserve(p1.size() + p2.size());
        merged.insert(merged.end(), p1.begin(), p1.end());
        merged.insert(merged.end(), p2.begin(), p2.end());
	return merged;
}

string newTemp(){
	return "t"+to_string(tempCount++);
}

void MakeIRFile()
{
	int tabs=0;
	for(int i=0;i<instructions.size();i++)
	{
		if(instructions[i][1]=="EndFunc") tabs--;
		cout << i+1 << "\t" << string(tabs,'\t');
		code_out << i+1 << "\t" << string(tabs,'\t');
		if(instructions[i][0]=="0")
		{
			for(int j=1;j<instructions[i].size();j++)
			{
				cout << instructions[i][j] << (instructions[i][j].length()?" ":"");
				code_out << instructions[i][j] << (instructions[i][j].length()?" ":"");
			}
			if(instructions[i][1]=="BeginFunc") tabs++;
		}
		else
		{
			cout << instructions[i][1] << " = " << instructions[i][3] << " " << instructions[i][2] << " " << instructions[i][4];
			code_out << instructions[i][1] << " = " << instructions[i][3] << " " << instructions[i][2] << " " << instructions[i][4];
		}
		cout << endl;
		code_out << endl;
	}
}


ste* setup_global_sym_table(ste* curr_ste){
    curr_ste->lexeme = "global_head";
    curr_ste->type = "GLOBAL_HEAD";
    curr_ste = insert_entry_same_scope(curr_ste, "ATOM_KEYWORDS", "True", "RESERVED_KEYWORD", -1, -1);
    curr_ste = insert_entry_same_scope(curr_ste, "ATOM_KEYWORDS", "False", "RESERVED_KEYWORD", -1, -1);
    curr_ste = insert_entry_same_scope(curr_ste, "ELSE", "else", "RESERVED_KEYWORD", -1, -1);
    curr_ste = insert_entry_same_scope(curr_ste, "ATOM_KEYWORDS", "None", "RESERVED_KEYWORD", -1, -1);
    curr_ste = insert_entry_same_scope(curr_ste, "BREAK", "break", "RESERVED_KEYWORD", -1, -1);
    curr_ste = insert_entry_same_scope(curr_ste, "IN", "in", "RESERVED_KEYWORD", -1, -1);
    curr_ste = insert_entry_same_scope(curr_ste, "CLASS", "class", "RESERVED_KEYWORD", -1, -1);
    curr_ste = insert_entry_same_scope(curr_ste, "IS", "is", "RESERVED_KEYWORD", -1, -1);
    curr_ste = insert_entry_same_scope(curr_ste, "RETURN", "return", "RESERVED_KEYWORD", -1, -1);\
    curr_ste = insert_entry_same_scope(curr_ste, "AND", "and", "RESERVED_KEYWORD", -1, -1);
    curr_ste = insert_entry_same_scope(curr_ste, "CONTINUE", "continue", "RESERVED_KEYWORD", -1, -1);
    curr_ste = insert_entry_same_scope(curr_ste, "FOR", "for", "RESERVED_KEYWORD", -1, -1);
    curr_ste = insert_entry_same_scope(curr_ste, "DEF", "def", "RESERVED_KEYWORD", -1, -1);
    curr_ste = insert_entry_same_scope(curr_ste, "WHILE", "while", "RESERVED_KEYWORD", -1, -1);
    curr_ste = insert_entry_same_scope(curr_ste, "GLOBAL", "global", "RESERVED_KEYWORD", -1, -1);
    curr_ste = insert_entry_same_scope(curr_ste, "NOT", "not", "RESERVED_KEYWORD", -1, -1);
    curr_ste = insert_entry_same_scope(curr_ste, "ELIF", "elif", "RESERVED_KEYWORD", -1, -1);
    curr_ste = insert_entry_same_scope(curr_ste, "IF", "if", "RESERVED_KEYWORD", -1, -1);
    curr_ste = insert_entry_same_scope(curr_ste, "OR", "or", "RESERVED_KEYWORD", -1, -1);
    return curr_ste;
}



int main(int argc, char* argv[]){    
    /* cout<<"Hello\n"; */
    FILE* yyin = fopen(argv[1],"r");
    yyrestart(yyin); 

    /* bool inset = false, outset = false; */
    indent_stack.push(0);


    /* for (int i=0; i< argc; i++){
        if (strcmp(argv[i], "-help") == 0){
            cerr<<"Usage: ./run.sh [-help] [-input <filename>] [-output <filename>] [-verbose]\n";
            cerr<< "Example: ./myASTGenerator -input input.txt -output output.txt\n";
        }
        else if (strcmp(argv[i], "-input") == 0){
            yyin = fopen(argv[i+1], "r");
            yyrestart(yyin);
            inset = true;
        }
        else if (strcmp(argv[i], "-output") == 0){
            freopen(argv[i+1], "w", stdout);
            outset = true;
        }
        else if (strcmp(argv[i], "-verbose") == 0){
            cerr<<"Verbose Output directed to parser.output\n";
        }
    }
    if (!inset){
        cerr<< "Input not set, see help\n";
        return 0;
    }
    if (!outset){
        cerr<< "Output not set, see help\n";
        return 0;
    }  */

/*--------------------------------------------------------------*/

        // Open the output file
        /* fout.open(output_file.c_str(),ios::out); */
        code_out.open("./output/3AC.txt",ios::out);
        // Get the DOT file template from the file
        /* ifstream infile("./DOT_Template.txt"); */
        /* string line; */
        /* while (getline(infile, line)) */
                /* fout << line << endl; */

/*--------------------------------------------------------------*/

    instCount=0;
    tempCount=0;
    /* yydebug=1; */
    current_ste = setup_global_sym_table(current_ste);
    /* cout<<"Parsing Started\n"; */
    yyparse();
    fclose(yyin); 

    print_ste(global_sym_table,0);

/*--------------------------------------------------------------*/

// Create 3AC file
    MakeIRFile();

// Close the output file
    code_out.close();

/*--------------------------------------------------------------*/
    return 0;

}