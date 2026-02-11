#ifndef TCP_H
#define TCP_H

#include "LaunchMethod.h"

class TCP : public LaunchMethod
{
public:
    std::string GetName() override { return "tcp"; }
    void GetOptions(options_description& desc) override;
    bool CheckOptions(variables_map& options) override;

    std::unique_ptr<Launcher> MakeLauncher(variables_map& options) override;
};

#endif // TCP_H
