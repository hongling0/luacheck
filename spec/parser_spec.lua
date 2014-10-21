local parser = require "luacheck.parser"

local function strip_locations(ast)
   ast.line = nil
   ast.column = nil
   ast.offset = nil

   for i=1, #ast do
      if type(ast[i]) == "table" then
         strip_locations(ast[i])
      end
   end
end

local function get_ast(src, keep_locations)
   local ast = parser(src)
   assert.is_table(ast)

   if not keep_locations then
      strip_locations(ast)
   end

   return ast
end

local function get_node(src)
   return get_ast(src)[1]
end

describe("parser", function()
   it("parses empty source correctly", function()
      assert.same({}, get_ast(" "))
   end)

   it("parses return statement correctly", function()
      assert.same({tag = "Return"}, get_node("return"))
      assert.same({tag = "Return",
                     {tag = "Number", "1"}
                  }, get_node("return 1"))
      assert.same({tag = "Return",
                     {tag = "Number", "1"},
                     {tag = "String", "foo"}
                  }, get_node("return 1, 'foo'"))
      assert.is_nil(parser("return 1,"))
   end)

   it("parses labels correctly", function()
      assert.same({tag = "Label", "fail"}, get_node("::fail::"))
      assert.same({tag = "Label", "fail"}, get_node("::\nfail\n::"))
      assert.is_nil(parser("::::"))
      assert.is_nil(parser("::1::"))
   end)

   it("parses goto correctly", function()
      assert.same({tag = "Goto", "fail"}, get_node("goto fail"))
      assert.is_nil(parser("goto"))
      assert.is_nil(parser("goto foo, bar"))
   end)

   it("parses break correctly", function()
      assert.same({tag = "Break"}, get_node("break"))
      assert.is_nil(parser("break fail"))
   end)

   it("parses do end correctly", function()
      assert.same({tag = "Do"}, get_node("do end"))
      assert.is_nil(parser("do"))
      assert.is_nil(parser("do until false"))
   end)

   it("parses while do end correctly", function()
      assert.same({tag = "While",
                     {tag = "True"},
                     {}
                  }, get_node("while true do end"))
      assert.is_nil(parser("while"))
      assert.is_nil(parser("while true"))
      assert.is_nil(parser("while true do"))
      assert.is_nil(parser("while do end"))
      assert.is_nil(parser("while true, false do end"))
   end)

   it("parses repeat until correctly", function()
      assert.same({tag = "Repeat",
                     {},
                     {tag = "True"}
                  }, get_node("repeat until true"))
      assert.is_nil(parser("repeat"))
      assert.is_nil(parser("repeat until"))
      assert.is_nil(parser("repeat until true, false"))
   end)

   describe("when parsing if", function()
      it("parses if then end correctly", function()
         assert.same({tag = "If",
                        {tag = "True"},
                        {}
                     }, get_node("if true then end"))
         assert.is_nil(parser("if"))
         assert.is_nil(parser("if true"))
         assert.is_nil(parser("if true then"))
         assert.is_nil(parser("if then end"))
         assert.is_nil(parser("if true, false then end"))
      end)

      it("parses if then else end correctly", function()
         assert.same({tag = "If",
                        {tag = "True"},
                        {},
                        {}
                     }, get_node("if true then else end"))
         assert.is_nil(parser("if true then else"))
         assert.is_nil(parser("if true then else else end"))
      end)

      it("parses if then elseif then end correctly", function()
         assert.same({tag = "If",
                        {tag = "True"},
                        {},
                        {tag = "False"},
                        {}
                     }, get_node("if true then elseif false then end"))
         assert.is_nil(parser("if true then elseif end"))
         assert.is_nil(parser("if true then elseif then end"))
      end)

      it("parses if then elseif then else end correctly", function()
         assert.same({tag = "If",
                        {tag = "True"},
                        {},
                        {tag = "False"},
                        {},
                        {}
                     }, get_node("if true then elseif false then else end"))
         assert.is_nil(parser("if true then elseif false then else"))
      end)
   end)

   describe("when parsing for", function()
      it("parses fornum correctly", function()
         assert.same({tag = "Fornum",
                        {tag = "Id", "i"},
                        {tag = "Number", "1"},
                        {tag = "Op", "len", {tag = "Id", "t"}},
                        {}
                     }, get_node("for i=1, #t do end"))
         assert.is_nil(parser("for"))
         assert.is_nil(parser("for i"))
         assert.is_nil(parser("for i ~= 2"))
         assert.is_nil(parser("for i = 2 do end"))
         assert.is_nil(parser("for i=1, #t do"))
         assert.is_nil(parser("for (i)=1, #t do end"))
         assert.is_nil(parser("for 3=1, #t do end"))
      end)

      it("parses fornum with step correctly", function()
         assert.same({tag = "Fornum",
                        {tag = "Id", "i"},
                        {tag = "Number", "1"},
                        {tag = "Op", "len", {tag = "Id", "t"}},
                        {tag = "Number", "2"},
                        {}
                     }, get_node("for i=1, #t, 2 do end"))
         assert.is_nil(parser("for i=1, #t, 2, 3 do"))
      end)

      it("parses forin correctly", function()
         assert.same({tag = "Forin", {
                           {tag = "Id", "i"}
                        }, {
                           {tag = "Id", "t"}
                        },
                        {}
                     }, get_node("for i in t do end"))
         assert.same({tag = "Forin", {
                           {tag = "Id", "i"},
                           {tag = "Id", "j"}
                        }, {
                           {tag = "Id", "t"},
                           {tag = "String", "foo"}
                        },
                        {}
                     }, get_node("for i, j in t, 'foo' do end"))
         assert.is_nil(parser("for in foo do end"))
         assert.is_nil(parser("for i in do end"))
      end)
   end)

   describe("when parsing functions", function()
      it("parses simple function correctly", function()
         assert.same({tag = "Set", {
                           {tag = "Id", "a"}
                        }, {
                           {tag = "Function", {}, {}}
                        }
                     }, get_node("function a() end"))
         assert.is_nil(parser("function"))
         assert.is_nil(parser("function a"))
         assert.is_nil(parser("function a("))
         assert.is_nil(parser("function a()"))
         assert.is_nil(parser("function (a)()"))
         assert.is_nil(parser("function() end"))
         assert.is_nil(parser("(function a() end)"))
         assert.is_nil(parser("function a() end()"))
      end)

      it("parses simple function with arguments correctly", function()
         assert.same({tag = "Set", {
                           {tag = "Id", "a"}
                        }, {
                           {tag = "Function", {{tag = "Id", "b"}}, {}}
                        }
                     }, get_node("function a(b) end"))
         assert.same({tag = "Set", {
                           {tag = "Id", "a"}
                        }, {
                           {tag = "Function", {{tag = "Id", "b"}, {tag = "Id", "c"}}, {}}
                        }
                     }, get_node("function a(b, c) end"))
         assert.same({tag = "Set", {
                           {tag = "Id", "a"}
                        }, {
                           {tag = "Function", {{tag = "Id", "b"}, {tag = "Dots"}}, {}}
                        }
                     }, get_node("function a(b, ...) end"))
         assert.is_nil(parser("function a(b, ) end"))
         assert.is_nil(parser("function a(b.c) end"))
         assert.is_nil(parser("function a((b)) end"))
         assert.is_nil(parser("function a(..., ...) end"))
      end)

      it("parses field function correctly", function()
         assert.same({tag = "Set", {
                           {tag = "Index", {tag = "Id", "a"}, {tag = "String", "b"}}
                        }, {
                           {tag = "Function", {}, {}}
                        }
                     }, get_node("function a.b() end"))
         assert.same({tag = "Set", {
                           {tag = "Index",
                              {tag = "Index", {tag = "Id", "a"}, {tag = "String", "b"}},
                              {tag = "String", "c"}
                           }
                        }, {
                           {tag = "Function", {}, {}}
                        }
                     }, get_node("function a.b.c() end"))
         assert.is_nil(parser("function a[b]() end"))
         assert.is_nil(parser("function a.() end"))
      end)

      it("parses method function correctly", function()
         assert.same({tag = "Set", {
                           {tag = "Index", {tag = "Id", "a"}, {tag = "String", "b"}}
                        }, {
                           {tag = "Function", {{tag = "Id", "self"}}, {}}
                        }
                     }, get_node("function a:b() end"))
         assert.same({tag = "Set", {
                           {tag = "Index",
                              {tag = "Index", {tag = "Id", "a"}, {tag = "String", "b"}},
                              {tag = "String", "c"}
                           }
                        }, {
                           {tag = "Function", {{tag = "Id", "self"}}, {}}
                        }
                     }, get_node("function a.b:c() end"))
         assert.is_nil(parser("function a:b.c() end"))
      end)
   end)

   describe("when parsing local declarations", function()
      it("parses simple local declaration correctly", function()
         assert.same({tag = "Local", {
                           {tag = "Id", "a"}
                        }
                     }, get_node("local a"))
         assert.same({tag = "Local", {
                           {tag = "Id", "a"},
                           {tag = "Id", "b"}
                        }
                     }, get_node("local a, b"))
         assert.is_nil(parser("local"))
         assert.is_nil(parser("local a,"))
         assert.is_nil(parser("local a.b"))
         assert.is_nil(parser("local a[b]"))
         assert.is_nil(parser("local (a)"))
      end)

      it("parses local declaration with assignment correctly", function()
         assert.same({tag = "Local", {
                           {tag = "Id", "a"}
                        }, {
                           {tag = "Id", "b"}
                        }
                     }, get_node("local a = b"))
         assert.same({tag = "Local", {
                           {tag = "Id", "a"},
                           {tag = "Id", "b"}
                        }, {
                           {tag = "Id", "c"},
                           {tag = "Id", "d"}
                        }
                     }, get_node("local a, b = c, d"))
         assert.is_nil(parser("local a = "))
         assert.is_nil(parser("local a = b,"))
         assert.is_nil(parser("local a.b = c"))
         assert.is_nil(parser("local a[b] = c"))
         assert.is_nil(parser("local a, (b) = c"))
      end)

      it("parses local function declaration correctly", function()
         assert.same({tag = "Localrec",
                        {tag = "Id", "a"}, 
                        {tag = "Function", {}, {}}
                     }, get_node("local function a() end"))
         assert.is_nil(parser("local function"))
         assert.is_nil(parser("local function a.b() end"))
      end)
   end)

   describe("when parsing assignments", function()
      it("parses single target assignment correctly", function()
         assert.same({tag = "Set", {
                           {tag = "Id", "a"}
                        }, {
                           {tag = "Id", "b"}
                        }
                     }, get_node("a = b"))
         assert.same({tag = "Set", {
                           {tag = "Index", {tag = "Id", "a"}, {tag = "String", "b"}}
                        }, {
                           {tag = "Id", "c"}
                        }
                     }, get_node("a.b = c"))
         assert.same({tag = "Set", {
                           {tag = "Index",
                              {tag = "Index", {tag = "Id", "a"}, {tag = "String", "b"}},
                              {tag = "String", "c"}
                           }
                        }, {
                           {tag = "Id", "d"}
                        }
                     }, get_node("a.b.c = d"))
         assert.same({tag = "Set", {
                           {tag = "Index",
                              {tag = "Invoke",
                                 {tag = "Call", {tag = "Id", "f"}},
                                 {tag = "String", "g"}
                              },
                              {tag = "Number", "9"}
                           }
                        }, {
                           {tag = "Id", "d"}
                        }
                     }, get_node("(f():g())[9] = d"))
         assert.is_nil(parser("a"))
         assert.is_nil(parser("a = "))
         assert.is_nil(parser("a() = b"))
         assert.is_nil(parser("(a) = b"))
         assert.is_nil(parser("1 = b"))
      end)

      it("parses multi assignment correctly", function()
         assert.same({tag = "Set", {
                           {tag = "Id", "a"},
                           {tag = "Id", "b"}
                        }, {
                           {tag = "Id", "c"},
                           {tag = "Id", "d"}
                        }
                     }, get_node("a, b = c, d"))
         assert.is_nil(parser("a, b"))
         assert.is_nil(parser("a, = b"))
         assert.is_nil(parser("a, b = "))
         assert.is_nil(parser("a, b = c,"))
         assert.is_nil(parser("a, b() = c"))
         assert.is_nil(parser("a, (b) = c"))
      end)
   end)

   describe("when parsing expression statements", function()
      it("parses calls correctly", function()
         assert.same({tag = "Call",
                        {tag = "Id", "a"}
                     }, get_node("a()"))
         assert.same({tag = "Call",
                        {tag = "Id", "a"},
                        {tag = "String", "b"}
                     }, get_node("a'b'"))
         assert.same({tag = "Call",
                        {tag = "Id", "a"},
                        {tag = "Table"}
                     }, get_node("a{}"))
         assert.same({tag = "Call",
                        {tag = "Id", "a"},
                        {tag = "Id", "b"}
                     }, get_node("a(b)"))
         assert.same({tag = "Call",
                        {tag = "Id", "a"},
                        {tag = "Id", "b"}
                     }, get_node("(a)(b)"))
         assert.same({tag = "Call",
                        {tag = "Call",
                           {tag = "Id", "a"},
                           {tag = "Id", "b"}
                        }
                     }, get_node("(a)(b)()"))
         assert.is_nil(parser("()()"))
         assert.is_nil(parser("a("))
         assert.is_nil(parser("1()"))
         assert.is_nil(parser("'foo'()"))
         assert.is_nil(parser("function() end ()"))
      end)

      it("parses method calls correctly", function()
         assert.same({tag = "Invoke",
                        {tag = "Id", "a"},
                        {tag = "String", "b"}
                     }, get_node("a:b()"))
         assert.same({tag = "Invoke",
                        {tag = "Id", "a"},
                        {tag = "String", "b"},
                        {tag = "String", "c"}
                     }, get_node("a:b'c'"))
         assert.same({tag = "Invoke",
                        {tag = "Id", "a"},
                        {tag = "String", "b"},
                        {tag = "Table"}
                     }, get_node("a:b{}"))
         assert.same({tag = "Invoke",
                        {tag = "Id", "a"},
                        {tag = "String", "b"},
                        {tag = "Id", "c"}
                     }, get_node("a:b(c)"))
         assert.same({tag = "Invoke",
                        {tag = "Id", "a"},
                        {tag = "String", "b"},
                        {tag = "Id", "c"}
                     }, get_node("(a):b(c)"))
         assert.same({tag = "Invoke",
                        {tag = "Invoke",
                           {tag = "Id", "a"},
                           {tag = "String", "b"}
                        }, {tag = "String", "c"}
                     }, get_node("a:b():c()"))
         assert.is_nil(parser("1:b()"))
         assert.is_nil(parser("'':a()"))
         assert.is_nil(parser("function()end:b()"))
         assert.is_nil(parser("a:b:c()"))
         assert.is_nil(parser("a:"))
      end)
   end)

   describe("when parsing multiple statements", function()
      it("does not allow statements after return", function()
         assert.is_nil(parser("return break"))
         assert.is_nil(parser("return; break"))
         assert.is_nil(parser("return 1 break"))
         assert.is_nil(parser("return 1; break"))
         assert.is_nil(parser("return 1, 2 break"))
         assert.is_nil(parser("return 1, 2; break"))
      end)

      pending("<add more tests here>")
   end)
end)