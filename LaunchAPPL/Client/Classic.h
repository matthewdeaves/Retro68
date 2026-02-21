#ifndef CLASSIC_H
#define CLASSIC_H

#include "LaunchMethod.h"

class Classic : public LaunchMethod
{
public:
    std::string GetName() override { return "classic"; }

    bool CheckPlatform() override;
    std::unique_ptr<Launcher> MakeLauncher(variables_map& options) override;
};

#endif // CLASSIC_H
