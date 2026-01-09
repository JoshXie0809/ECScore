enum PluginInstallError: Error {
    case unkownError
    case installManager_NotFound
    case registryOrEntities_NotFound
    case notPlatformPlugin
    case pluginOrRequirements_WithUnkownType
}

extension BasePlatform {
    func install<T: Platform_Plugin>(plugin: T) throws(PluginInstallError) {
        guard 
            let registry = self.registry,
            self.entities != nil
        else {
            // registry or entities not found
            throw .registryOrEntities_NotFound
        }
        
        if !registry.contains(Platform_Plugin_Manager.self) {
            // check type is manager
            if T.self is Platform_Plugin_Manager {
                let manager = plugin as! Platform_Plugin_Manager
                manager.initBasePF(base: self)
            } else {
                throw .installManager_NotFound
            }
        }
        let manager_rid = registry.register(Platform_Plugin_Manager.self)

        guard let manager = self
            .rawGetStorage(for: manager_rid)?
            .getWithDenseIndex_Uncheck(0) as? Platform_Plugin_Manager 
        else {
            throw .installManager_NotFound
        }

        // registry is found
        // entities is found
        // manager  is found

        try manager.install(plugin, self)

        return
    }
}

protocol Platform_Plugin_Manager {
    func initBasePF(base: BasePlatform)
    var pluginsRequirements: [[Int]] { get }
    func install<T: Platform_Plugin>(_ plugin: T, _ base: BasePlatform) throws(PluginInstallError)
}

protocol Platform_Plugin {
    var requirements: [any Any.Type] { get }
    func createPFStorage() -> any AnyPlatformStorage
}

final class Plugin_Platform_Ver0: Platform, Platform_Plugin_Manager, Platform_Plugin, Component {
    private(set) var pluginsRequirements: [[Int]] = []
    
    init(base: BasePlatform) {
        guard let registry = base.registry else {
            fatalError("Cannot find registry in base Platform")
        }

        guard let entities = base.entities else {
            fatalError("Cannot find entities in base Platform")
        }

        let before_register_storage_count = base.storages.count
        self.pluginsRequirements.append(contentsOf: repeatElement([], count: before_register_storage_count))

        let plugin_pf_rid = registry.register(Platform_Plugin_Manager.self)
        
        ensureStorageCapacity(base: base)
        
        let storage = PFStorage<Plugin_Platform_Ver0>()
        // will not out of bound because we ensure it
        base.storages[plugin_pf_rid.id] = storage

        let plugin_pf_eid = entities.spawn(1)[0]
        storage.add(eid: plugin_pf_eid, component: self)
    }

    private func ensureStorageCapacity(base: BasePlatform) {
        let registry = base.registry! // check while init
        let rid_count = registry.count
        let needed = rid_count - base.storages.count
        
        if needed > 0 {
            base.storages.append( contentsOf: repeatElement(nil, count: needed) )
            self.pluginsRequirements.append(contentsOf: repeatElement([], count: needed))
        }
    }

    func initBasePF(base: BasePlatform) {
        _ = Plugin_Platform_Ver0(base: base)
    }

    // other manager exists
    func install<P: Any>(_ temp_plugin: P, _ base: BasePlatform) throws(PluginInstallError) {
        let registry = base.registry!
        let entities = base.entities!

        guard !registry.contains(P.self) else {
            // not double register
            return
        }

        guard let plugin = temp_plugin as? Platform_Plugin else {
            throw .notPlatformPlugin
        }

        let plugin_rid = registry.register(P.self)

        var plugin_requirements_rids: [Int] = []
        for reqType in plugin.requirements {
            if !registry.contains(reqType) { 
                if reqType is Platform_Plugin {
                    // try install(reqType, base)

                } 
                else if reqType is Component {
                    _ = registry.register(reqType)
                }
                else {
                    throw .pluginOrRequirements_WithUnkownType
                }
            }
            
            let req_rid = registry.register(reqType.self)
            plugin_requirements_rids.append(req_rid.id)
        }

        ensureStorageCapacity(base: base)

        // build storage
        let plugin_pfs = plugin.createPFStorage()
        base.storages[plugin_rid.id] = plugin_pfs
        let plugin_eid = entities.spawn(1)[0]
        
        plugin_pfs.rawAdd(eid: plugin_eid, component: temp_plugin)
    }

    // as a Plugin
    private(set) var requirements: [any Any.Type] = [ RegistryPlatform.self, Platform_Entitiy.self ]


    func createPFStorage() -> any AnyPlatformStorage {
        return PFStorage<Self>()
    }
}