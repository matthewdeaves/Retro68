#ifndef MINIVMAC_H
#define MINIVMAC_H

#include "LaunchMethod.h"

class MiniVMac : public LaunchMethod
{
public:
    std::string GetName() override { return "minivmac"; }
    void GetOptions(options_description& desc) override;
    bool CheckOptions(variables_map& options) override;

    std::unique_ptr<Launcher> MakeLauncher(variables_map& options) override;
};

#endif // MINIVMAC_H
