# hmgsign

The mod signer. It is [HMG-API](https://github.com/VysseCodes/HMG-API)'s own `Signing` and `Json`
classes, built on a desktop JDK with `Engine.java` from this folder standing in for HMG-API's
engine. HMG-API checks the same signature at install time.

`build.sh` fetches the two upstream files from the pinned commit below, then compiles them with
`Engine.java`. The upstream files stay under their own licence (AGPL-3.0) and are not part of
this repository.

| file | upstream path | commit |
|---|---|---|
| `Signing.java` | `core/runtime/java/hmgapi/engine/Signing.java` | `4fab4376adae65b67025046539963a68fb37f76f` |
| `Json.java` | `core/runtime/java/hmgapi/engine/Json.java` | `4fab4376adae65b67025046539963a68fb37f76f` |

Once built, the signer can also be run by hand:

```
java -cp build/hmgsign hmgapi.engine.Signing keygen <key file>     # a new author key (+ .pub)
java -cp build/hmgsign hmgapi.engine.Signing sign <mod dir> <key file>
java -cp build/hmgsign hmgapi.engine.Signing verify <mod dir> [<uuid>]
```

Mod releases from this repository are signed with the author key in `keys/author.key.pub`
(uuid in `keys/uuid.txt`). HMG-API installs an update only when it comes from the same key.
The private key is never committed.
