#ifndef SSH_H
#define SSH_H

#include "LaunchMethod.h"

class SSH : public LaunchMethod
{
public:
    std::string GetName() override { return "ssh"; }
    void GetOptions(options_description& desc) override;
    bool CheckOptions(variables_map& options) override;

    std::unique_ptr<Launcher> MakeLauncher(variables_map& options) override;
};

#endif // SSH_H
