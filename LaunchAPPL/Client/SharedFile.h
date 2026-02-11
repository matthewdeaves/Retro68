#pragma once

#include "LaunchMethod.h"

class SharedFile : public LaunchMethod
{
public:
    std::string GetName() override { return "shared"; }
    void GetOptions(options_description& desc) override;
    bool CheckOptions(variables_map& options) override;

    std::unique_ptr<Launcher> MakeLauncher(variables_map& options) override;
};
