#include <stdio.h>
#include "Test.h"

int main(void)
{
    /*
     * Test stdio functionality by writing to a file using fopen/fprintf.
     *
     * Note: Due to emulator environment constraints, we first initialize
     * file I/O using direct Mac File Manager calls (via TEST_LOG_SIZED),
     * then verify stdio works on top of this.
     */

    /* Initialize file system state with a dummy write */
    TEST_LOG_SIZED("", 0);

    /* Now test actual stdio operations */
    FILE *f = fopen("out", "w");
    if (f == NULL)
        return 1;
    setvbuf(f, NULL, _IONBF, 0);
    fprintf(f, "OK\n");
    fclose(f);
    return 0;
}
