#ifndef RESOURCEDEFINITIONS_H
#define RESOURCEDEFINITIONS_H

#include <iosfwd>
#include <memory>
#include <map>

#include "Expression.h"
#include "ResType.h"

#include "location.hh"

class TypeSpec
{
    ResType type;
    int id;
public:
    static const int noID = 65536;

    TypeSpec() : id(noID) {}
    explicit TypeSpec(ResType type) : type(type), id(noID) {}
    TypeSpec(ResType type, int id) : type(type), id(id) {}

    ResType getType() const { return type; }
    int getID() const { return id; }

    bool hasID() const { return id != noID; }

    bool operator<(TypeSpec y) const
    {
        if(type < y.type)
            return true;
        else if(y.type < type)
            return false;
        else
            return id < y.id;
    }
};

std::ostream& operator<<(std::ostream& out, TypeSpec ts);


class ResourceCompiler;

class Field
{
public:
    yy::location location;

    virtual ~Field() = default;

    virtual bool needsValue() { return true; }

    virtual void compile(ExprPtr expr, ResourceCompiler *compiler, bool prePass) = 0;

    virtual ExprPtr lookupNamedValue(const std::string&) { return nullptr; }
};
typedef std::shared_ptr<Field> FieldPtr;

class SimpleField : public Field
{
public:
    enum class Type
    {
        boolean, byte, integer, longint, rect, point, char_,
        pstring, wstring, string, bitstring
    };

    enum class Attrs
    {
        none = 0, hex = 1, key = 2, unsigned_ = 4, literal = 8, binary = 16
    };

    Type type;
    Attrs attrs = Attrs::none;
    ExprPtr arrayCount;

    ExprPtr    value;
    std::map<std::string, ExprPtr> namedValues;
    ExprPtr lastNamedValue;

    void addNamedValue(const std::string& n);
    void addNamedValue(const std::string& n, ExprPtr val);
    ExprPtr lookupNamedValue(const std::string& n) override;

    bool needsValue() override;
    void compile(ExprPtr expr, ResourceCompiler *compiler, bool prePass) override;

private:
    void compileString(ExprPtr expr, ResourceCompiler *compiler, bool prePass);
    void compileInt(ExprPtr expr, ResourceCompiler *compiler, bool prePass);
    void compileCompound(ExprPtr expr, ResourceCompiler *compiler, bool prePass);
};
typedef std::shared_ptr<SimpleField> SimpleFieldPtr;

class FillAlignField : public Field
{
public:
    enum class Type
    {
        bit, nibble, byte, word, long_
    };

    FillAlignField(Type type, bool isAlign, ExprPtr count = ExprPtr());
    bool needsValue() override;
    void compile(ExprPtr expr, ResourceCompiler *compiler, bool prePass) override;
private:
    Type type;
    ExprPtr count;
    bool isAlign;
};

inline SimpleField::Attrs operator|(SimpleField::Attrs a, SimpleField::Attrs b)
{
    return SimpleField::Attrs( int(a) | int(b) );
}


class LabelField : public Field
{
    std::string name;
public:
    explicit LabelField(const std::string& name);

    bool needsValue() override;
    void compile(ExprPtr expr, ResourceCompiler *compiler, bool prePass) override;
};
typedef std::shared_ptr<LabelField> LabelFieldPtr;


class FieldList : public Field
{
protected:
    std::vector<FieldPtr> fields;
public:
    virtual ~FieldList();
    void addField(FieldPtr field, yy::location loc);
    void addLabel(const std::string& name, yy::location loc);

    void compile(ExprPtr expr, ResourceCompiler *compiler, bool prePass) override;
};
typedef std::shared_ptr<FieldList> FieldListPtr;


class ArrayField : public FieldList
{
    std::string name;
    ExprPtr arrayCount;
public:
    ArrayField(const std::string& name /* or empty */, ExprPtr count /* may be null*/);

    void compile(ExprPtr expr, ResourceCompiler *compiler, bool prePass) override;
};
typedef std::shared_ptr<ArrayField> ArrayFieldPtr;

class SwitchField : public Field
{
    std::map<std::string, FieldListPtr> cases;
public:
    void addCase(const std::string& name, FieldListPtr alternative);

    void compile(ExprPtr expr, ResourceCompiler *compiler, bool prePass) override;
};
typedef std::shared_ptr<SwitchField> SwitchFieldPtr;

class TypeDefinition : public FieldList
{
};
typedef std::shared_ptr<TypeDefinition> TypeDefinitionPtr;

#endif // RESOURCEDEFINITIONS_H
