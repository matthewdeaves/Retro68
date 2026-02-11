#ifndef EXPRESSION_H
#define EXPRESSION_H

#include <memory>
#include <vector>

#include "location.hh"

class ResourceCompiler;

class Expression;
class CompoundExpr;
class IdentifierExpr;
class CaseExpr;
typedef std::shared_ptr<Expression> ExprPtr;
typedef std::shared_ptr<CompoundExpr> CompoundExprPtr;
typedef std::shared_ptr<IdentifierExpr> IdentifierExprPtr;
typedef std::shared_ptr<CaseExpr> CaseExprPtr;


enum class BinaryOp
{
    XOR, OR, AND, SHIFTLEFT, SHIFTRIGHT, EQUAL, NOTEQUAL, PLUS, MINUS, MULTIPLY, DIVIDE, CONCAT
};

enum class UnaryOp
{
    MINUS, COMPLEMENT
};

class TypeError
{
};

class Expression
{
public:
    yy::location location;

    explicit Expression(yy::location loc) : location(loc) {}

    virtual int evaluateInt(ResourceCompiler *ctx);
    virtual std::string evaluateString(ResourceCompiler *ctx);
    virtual ~Expression();

    void error(ResourceCompiler *ctx, const std::string& err);
};

class StringExpr : public Expression
{
    std::string str;
public:
    StringExpr(const std::string& str, yy::location loc) : Expression(loc), str(str) {}
    ~StringExpr();
    std::string evaluateString(ResourceCompiler *ctx) override;
};

class IntExpr : public Expression
{
    int val;
public:
    IntExpr(int val, yy::location loc) : Expression(loc), val(val) {}
    ~IntExpr();

    int evaluateInt(ResourceCompiler *ctx) override;
};

class CompoundExpr : public Expression
{
    std::vector<ExprPtr> items;
public:
    explicit CompoundExpr(yy::location loc) : Expression(loc) {}

    void addItem(ExprPtr item);
    ExprPtr getItem(int i) const { return items[i]; }
    int size() const { return items.size(); }

    ~CompoundExpr();
};

class CaseExpr : public Expression
{
    std::string tag;
    CompoundExprPtr expr;
    friend class SwitchField;
public:
    CaseExpr(const std::string& tag, CompoundExprPtr expr, yy::location loc);
};

class BinaryExpr : public Expression
{
    BinaryOp op;
    ExprPtr a, b;
public:
    BinaryExpr(BinaryOp op, ExprPtr a, ExprPtr b, yy::location loc)
        : Expression(loc), op(op), a(a), b(b) {}
    ~BinaryExpr();

    int evaluateInt(ResourceCompiler *ctx) override;
    std::string evaluateString(ResourceCompiler *ctx) override;
};

class UnaryExpr : public Expression
{
    UnaryOp op;
    ExprPtr a;
public:
    UnaryExpr(UnaryOp op, ExprPtr a, yy::location loc)
        : Expression(loc), op(op), a(a) {}
    ~UnaryExpr();

    int evaluateInt(ResourceCompiler *ctx) override;
};

class IdentifierExpr : public Expression
{
public:
    std::string id;
    std::vector<ExprPtr> arguments;
    IdentifierExpr(std::string id, yy::location loc);

    void addArgument(ExprPtr e);
    ExprPtr lookup(ResourceCompiler *ctx);
    int evaluateInt(ResourceCompiler *ctx) override;
    std::string evaluateString(ResourceCompiler *ctx) override;
};

class CountOfExpr : public Expression
{
    IdentifierExprPtr arg;
public:
    CountOfExpr(IdentifierExprPtr arg, yy::location loc) : Expression(loc), arg(arg) {}
    int evaluateInt(ResourceCompiler *ctx) override;
};

class ArrayIndexExpr : public Expression
{
    IdentifierExprPtr arg;
public:
    ArrayIndexExpr(IdentifierExprPtr arg, yy::location loc) : Expression(loc), arg(arg) {}
    int evaluateInt(ResourceCompiler *ctx) override;
};

class ReadExpr : public Expression
{
    ExprPtr arg;
public:
    ReadExpr(ExprPtr arg, yy::location loc) : Expression(loc), arg(arg) {}
    std::string evaluateString(ResourceCompiler *ctx) override;
};

class UnimplementedExpr : public Expression
{
    std::string msg;
public:
    UnimplementedExpr(const std::string& msg, yy::location loc) : Expression(loc), msg(msg) {}
    int evaluateInt(ResourceCompiler *ctx) override;
    std::string evaluateString(ResourceCompiler *ctx) override;
};

class PeekExpr : public Expression
{
    ExprPtr addr;
    ExprPtr offset;
    ExprPtr size;
public:
    PeekExpr(ExprPtr addr, ExprPtr offset, ExprPtr size, yy::location loc);
    PeekExpr(ExprPtr addr, int size, yy::location loc);
    int evaluateInt(ResourceCompiler *ctx) override;
};

#endif // EXPRESSION_H
