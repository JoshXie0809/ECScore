// View (with closure)

@inlinable
@inline(__always)
public func view<each T, each WT, each WOT> (
    base: borrowing Validated<BasePlatform, Proof_Handshake, Platform_Facts>,
    with: borrowing (repeat TypeToken<each T>),
    withTag: borrowing (repeat TypeToken<each WT>),
    withoutTag: borrowing (repeat TypeToken<each WOT>),
    _ action: (_: Int, _: repeat ComponentProxy<each T>) -> Void
) {
    let (vps, storages, wts, wots) = createViewPlans( base: base, with: (repeat each with), withTag: (repeat each withTag), withoutTag: (repeat each withoutTag) )
    if vps.count == 0 { return }
    executeViewPlans(
        viewPlans: vps, 
        storages: (repeat each storages), 
        wt_storages: (repeat each wts), 
        wot_storages: (repeat each wots), 
        action
    )
}

// static View (with system body)

@inlinable
@inline(__always)
public func view<S: SystemBody, each T, each WT, each WOT> (
    base: borrowing Validated<BasePlatform, Proof_Handshake, Platform_Facts>,
    with: borrowing (repeat TypeToken<each T>),
    withTag: borrowing (repeat TypeToken<each WT>),
    withoutTag: borrowing (repeat TypeToken<each WOT>),
    _ body: borrowing S
) where S.Components == (repeat ComponentProxy<each T>) 
{
    let (vps, storages, wts, wots) = createViewPlans( base: base, with: (repeat each with), withTag: (repeat each withTag), withoutTag: (repeat each withoutTag) )
    if vps.count == 0 { return }
    executeViewPlans(
        viewPlans: vps, 
        storages: (repeat each storages), 
        wt_storages: (repeat each wts), 
        wot_storages: (repeat each wots), 
        body
    )
}


// overloading view
// ##############################################################################################################

@inlinable
@inline(__always)
public func view<each T> (
    base: borrowing Validated<BasePlatform, Proof_Handshake, Platform_Facts>,
    with: borrowing (repeat TypeToken<each T>),
    _ action: (_: Int, _: repeat ComponentProxy<each T>) -> Void
) {
    view(base: base, with: (repeat each with), withTag: (), withoutTag: (), action)
}

@inlinable
@inline(__always)
public func view<each T, each WT> (
    base: borrowing Validated<BasePlatform, Proof_Handshake, Platform_Facts>,
    with: borrowing (repeat TypeToken<each T>),
    withTag: (repeat TypeToken<each WT>),
    _ action: (_: Int, _: repeat ComponentProxy<each T>) -> Void
) {
    view(base: base, with: (repeat each with), withTag: (repeat each withTag), withoutTag: (), action)
}

@inlinable
@inline(__always)
public func view<each T, each WOT> (
    base: borrowing Validated<BasePlatform, Proof_Handshake, Platform_Facts>,
    with: borrowing (repeat TypeToken<each T>),
    withoutTag: (repeat TypeToken<each WOT>),
    _ action: (_: Int, _: repeat ComponentProxy<each T>) -> Void
) {
    view(base: base, with: (repeat each with), withTag: (), withoutTag: (repeat each withoutTag), action)
}
// ##############################################################################################################

// overloading static view
// ##############################################################################################################

@inlinable
@inline(__always)
public func view<S: SystemBody, each T> (
    base: borrowing Validated<BasePlatform, Proof_Handshake, Platform_Facts>,
    with: borrowing (repeat TypeToken<each T>),
    _ body: borrowing S
) where S.Components == (repeat ComponentProxy<each T>) 
{
    view(base: base, with: (repeat each with), withTag: (), withoutTag: (), body)
}

@inlinable
@inline(__always)
public func view<S: SystemBody, each T, each WT> (
    base: borrowing Validated<BasePlatform, Proof_Handshake, Platform_Facts>,
    with: borrowing (repeat TypeToken<each T>),
    withTag: borrowing (repeat TypeToken<each WT>),
    _ body: borrowing S
) where S.Components == (repeat ComponentProxy<each T>) 
{
    view(base: base, with: (repeat each with), withTag: (repeat each withTag), withoutTag: (), body)
}

@inlinable
@inline(__always)
public func view<S: SystemBody, each T, each WOT> (
    base: borrowing Validated<BasePlatform, Proof_Handshake, Platform_Facts>,
    with: borrowing (repeat TypeToken<each T>),
    withoutTag: borrowing (repeat TypeToken<each WOT>),
    _ body: borrowing S
) where S.Components == (repeat ComponentProxy<each T>) 
{
    view(base: base, with: (repeat each with), withTag: (), withoutTag: (repeat each withoutTag), body)
}
// ##############################################################################################################

// single componet
@inline(__always)
public func view<T>(
    base: borrowing Validated<BasePlatform, Proof_Handshake, Platform_Facts>, 
    with: TypeToken<T>,
    _ action: (_: Int, _: ComponentProxy<T>) -> Void
) {
    let (vps, storage, _, _) = createViewPlans( base: base, with: with, withTag: (), withoutTag: () )
    
    for vp in vps {
        let blockId = vp.segmentIndex
        let count = storage.segments[blockId].pointee.count
        let dataPtr = storage.get_SparseSetL2_CompMutPointer_Uncheck(blockId)

        for i in 0..<count {
            // taskId = 0
            action(0, ComponentProxy<T>(pointer: dataPtr.advanced(by: i) ))
        }
    }

    _fixLifetime(storage)
}

// static single componet
@inline(__always)
public func view<S: SystemBody, T> (
    base: borrowing Validated<BasePlatform, Proof_Handshake, Platform_Facts>, 
    with: TypeToken<T>,
    _ body: borrowing S
) where S.Components == ComponentProxy<T>
{
    let (vps, storage, _, _) = createViewPlans( base: base, with: with, withTag: (), withoutTag: () )

    for vp in vps {
        let blockId = vp.segmentIndex
        let count = storage.segments[blockId].pointee.count
        let dataPtr = storage.get_SparseSetL2_CompMutPointer_Uncheck(blockId)

        for i in 0..<count {
            body.execute(
                taskId: 0, 
                components: ComponentProxy(pointer: dataPtr.advanced(by: i))
            )
        }
    }

    _fixLifetime(storage)
}
