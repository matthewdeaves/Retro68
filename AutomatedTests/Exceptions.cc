/*
     Copyright 2019 Wolfgang Thaller.

     This file is part of Retro68.

     Retro68 is free software: you can redistribute it and/or modify
     it under the terms of the GNU General Public License as published by
     the Free Software Foundation, either version 3 of the License, or
     (at your option) any later version.

     Retro68 is distributed in the hope that it will be useful,
     but WITHOUT ANY WARRANTY; without even the implied warranty of
     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
     GNU General Public License for more details.

     You should have received a copy of the GNU General Public License
     along with Retro68.  If not, see <http://www.gnu.org/licenses/>.
*/

extern "C" {
#include "Test.h"
}
#include <exception>
#include <stdlib.h>
#include <stdio.h>

class Foo
{
};

void foobar()
{
    throw Foo();
}

void UnexpectedExceptionOccurred()
{
    printf("std::unexpected called.\n");
    exit(1);
}

void UncaughtExceptionOccurred()
{
    printf("std::terminate called.\n");
    exit(1);
}

int main(int argc, char** argv)
{
    /* Initialize file system state for stdio to work reliably */
    TEST_LOG_SIZED("", 0);

    FILE *outFile = fopen("out", "w");
    if (outFile == NULL)
        return 1;
    setvbuf(outFile, NULL, _IONBF, 0);

    std::set_unexpected(&UnexpectedExceptionOccurred);
    std::set_terminate(&UncaughtExceptionOccurred);

    bool throwFail = false;
    bool catchFail = true;

    try
    {
        foobar();
        throwFail = true;
    }
    catch(...)
    {
        catchFail = false;
    }

    if(throwFail)
        fprintf(outFile, "throw didn't really throw\n");
    if(catchFail)
        fprintf(outFile, "catch block never entered\n");

    if(!throwFail && !catchFail)
        fprintf(outFile, "OK\n");
    fclose(outFile);
    return 0;
}
