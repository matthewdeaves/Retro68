#pragma once
#include "Launcher.h"
#include <vector>

class Stream;
class WaitableStream;

class StreamBasedLauncher : public Launcher
{
    WaitableStream *stream = nullptr;
    Stream *rStream = nullptr;
    std::vector<char> outputBytes;
    bool upgradeMode = false;
public:
    explicit StreamBasedLauncher(boost::program_options::variables_map& options);
    ~StreamBasedLauncher() override;

    bool Go(int timeout = 0) override;
    void DumpOutput() override;

protected:
    void SetupStream(WaitableStream* aStream, Stream* wrapped = nullptr);
private:
    void write(const void *p, size_t n);
    ssize_t read(void * p, size_t n);
};
