README
======

SYNOPSIS (CoffeeScript)
-----------------------

import {mydir} from '@jdeighan/coffee-utils/fs'
import {loadEnvFrom} from '@jdeighan/env'

dir = mydir(`import.meta.url`)
loadEnvFrom(dir)

