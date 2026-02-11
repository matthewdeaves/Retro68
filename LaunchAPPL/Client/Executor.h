#ifndef EXECUTOR_H
#define EXECUTOR_H

#include "LaunchMethod.h"

class Executor : public LaunchMethod
{
public:
    std::string GetName() override { return "executor"; }
    void GetOptions(options_description& desc) override;
    bool CheckOptions(variables_map& options) override;

    std::unique_ptr<Launcher> MakeLauncher(variables_map& options) override;
};

#endif // EXECUTOR_H
