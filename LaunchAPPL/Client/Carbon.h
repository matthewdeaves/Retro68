#ifndef CARBON_METHOD_H
#define CARBON_METHOD_H

#include "LaunchMethod.h"

class Carbon : public LaunchMethod
{
public:
    std::string GetName() override { return "carbon"; }

    bool CheckPlatform() override;
    std::unique_ptr<Launcher> MakeLauncher(variables_map& options) override;
};

#endif // CARBON_METHOD_H
