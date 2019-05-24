import Foundation
import CoreBluetooth
@testable import RxBluetoothKit

/// Class for providing peripherals and peripheral wrappers
class _PeripheralProvider {

    private let peripheralsBox: ThreadSafeBox<[_Peripheral]> = ThreadSafeBox(value: [])

    private let delegateWrappersBox: ThreadSafeBox<[UUID: CBPeripheralDelegateWrapperMock]> = ThreadSafeBox(value: [:])

    /// Provides `CBPeripheralDelegateWrapperMock` for specified `CBPeripheralMock`.
    ///
    /// If it was previously created it returns that object, so that there can be only
    /// one `CBPeripheralDelegateWrapperMock` per `CBPeripheralMock`.
    ///
    /// If not it creates new one.
    ///
    /// - parameter peripheral: _Peripheral for which to provide delegate wrapper
    /// - returns: Delegate wrapper for specified peripheral.
    func provideDelegateWrapper(for peripheral: CBPeripheralMock) -> CBPeripheralDelegateWrapperMock {
        let delegateWrapper = delegateWrappersBox.read({ $0[peripheral.uuidIdentifier] })
            ?? CBPeripheralDelegateWrapperMock()
        
        delegateWrappersBox.compareAndSet(
            compare: { $0[peripheral.uuidIdentifier] == nil },
            set: { $0[peripheral.uuidIdentifier] = delegateWrapper }
        )
        return delegateWrapper
    }

    /// Provides `_Peripheral` for specified `CBPeripheralMock`.
    ///
    /// If it was previously created it returns that object, so that there can be only one `_Peripheral`
    /// per `CBPeripheralMock`. If not it creates new one.
    ///
    /// - parameter peripheral: _Peripheral for which to provide delegate wrapper
    /// - returns: `_Peripheral` for specified peripheral.
    func provide(for cbPeripheral: CBPeripheralMock, centralManager: _CentralManager) -> _Peripheral {
        if let peripheral = find(cbPeripheral) {
            return peripheral
        } else {
            return createAndAddToBox(cbPeripheral, manager: centralManager)
        }
    }
    
    /// Provides a way to clear cache
    func clearCache() {
        peripheralsBox.writeSync {
            $0.removeAll()
        }
        delegateWrappersBox.writeSync {
            $0.removeAll()
        }
    }

    fileprivate func createAndAddToBox(_ cbPeripheral: CBPeripheralMock, manager: _CentralManager) -> _Peripheral {
        let newPeripheral = find(cbPeripheral) ?? new(peripheral: cbPeripheral, manager: manager)
        peripheralsBox.compareAndSet(
            compare: { peripherals in
                return !peripherals.contains(where: { $0.peripheral == cbPeripheral })
            },
            set: { peripherals in
                peripherals.append(newPeripheral)
            }
        )
        return newPeripheral
    }
    
    fileprivate func new(peripheral cbPeripheral: CBPeripheralMock,
                         manager: _CentralManager) -> _Peripheral {
        let delegateWrapper = provideDelegateWrapper(for: cbPeripheral)
        return _Peripheral(
            manager: manager,
            peripheral: cbPeripheral,
            delegateWrapper: delegateWrapper
        )
    }

    fileprivate func find(_ cbPeripheral: CBPeripheralMock) -> _Peripheral? {
        return peripheralsBox.read { peripherals in
            return peripherals.first(where: { $0.peripheral == cbPeripheral})
        }
    }
}
