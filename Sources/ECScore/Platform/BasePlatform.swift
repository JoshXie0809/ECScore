class BasePlatform : Platform {
    var storages: [AnyPlatformStorage?] = []

    func rawGetStorage(for rid: RegistryId) -> AnyPlatformStorage? {
        guard rid.id >= 0 && rid.id < storages.count else { return nil }
        return storages[rid.id]
    }
}

enum ManifestItem {
    case Plublic_Component( (Component.Type, Component) )
    case Private_Component( (Component.Type, Component) )
    case Platform_Registry
}


struct Manifest {
    var requirements: [ ManifestItem ]
}

struct EntityBuildTokens {
    let manifest: Manifest
}


// extension BasePlatform {

//     func interop(manifest: Manifest) -> EntityBuildTokens {
//         let registry = registry!

//         var genFn: [ any Component? ] = [ repeatElement(nil, count: manifest.requirements.count) ]

//         for item in manifest.requirements {
//             switch item {
//             case .Platform_Entities:
            

//             }

//         }


//     }
// }