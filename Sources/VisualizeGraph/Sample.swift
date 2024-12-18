import AttributeGraph
import SwiftUI

struct Sample: View {
    @State var snapshots: [GraphValue] = []
    @State var index: Int = 0

    var body: some View {
        VStack {
            if index >= 0, index < snapshots.count {
                Graphviz(dot: snapshots[index].dot)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Stepper(value: $index, label: {
                    Text("Step \(index + 1)/\(snapshots.count)")
                })
            }
        }
        .padding()
        .onAppear {
            snapshots = sample()
        }
    }
}

struct LayoutComputer: CustomStringConvertible {
    let sizeThatFits: (ProposedViewSize) -> CGSize
    let place: (CGRect) -> ()

    var description: String = ""
}

struct DisplayList: CustomStringConvertible {
    var items: [Item]

    struct Item: CustomStringConvertible {
        var name: String //
        var frame: CGRect

        var description: String {
            "\(name): \(frame)"
        }
    }

    var description: String {
        items.map { "\($0) "}.joined(separator: ", ")
    }
}

func sample() -> [GraphValue] {
    /*
     struct Nested: View {
     @State var toggle = false
     var body: some View {
         Color.blue.frame(width: toggle ? 50 : 100)
     }

     struct ContentView: View {
         var body: some View {
            HStack {
                Color.red
                Nested()
            }
         }
     }
     */

    let graph = AttributeGraph()
    let toggleStateProp = graph.input(name: "toggle", false)
    let inputSize = graph.input(name: "inputSize", CGSize(width: 200, height: 100))
    var frames: [CGRect] = [.null, .null]

    let redLayoutComputer = graph.rule(name: "red layoutComputer") {
        LayoutComputer { proposedSize in
            proposedSize.replacingUnspecifiedDimensions()
        } place: { rect in
            frames[0] = rect
        }
    }

    let nestedLayoutComputer = graph.rule(name: "nested layoutComputer") {
        let toggleSP = toggleStateProp.wrappedValue
        return LayoutComputer { proposedSize in
            let width: CGFloat = toggleSP ? 50 : 100
            let height = proposedSize.height ?? 10
            return CGSize(width: width, height: height)
        } place: { rect in
            frames[1] = rect
        }
    }
    
    let hstackLayoutComputer = graph.rule(name: "hstack layoutComputer") {
        let nestedLC = nestedLayoutComputer.wrappedValue
        let redLC = redLayoutComputer.wrappedValue
        return LayoutComputer { proposal in
            var remainder = proposal.width! // todo
            let childProposal = CGSize(width: remainder/2, height: proposal.height!)
            let nestedSize = nestedLC.sizeThatFits(.init(childProposal))
            remainder -= nestedSize.width
            let childProposal2 = CGSize(width: remainder, height: proposal.height!)
            let redResult = redLC.sizeThatFits(.init(childProposal2))
            let result = CGSize(width: redResult.width + nestedSize.width, height: max(redResult.height, nestedSize.height))
            return result
        } place: { rect in
            var remainder = rect.width
            let childProposal = CGSize(width: remainder/2, height: rect.height)
            let nestedSize = nestedLC.sizeThatFits(.init(childProposal))
            remainder -= nestedSize.width
            let childProposal2 = CGSize(width: remainder, height: rect.height)
            let redResult = redLC.sizeThatFits(.init(childProposal2))
            var currentPoint = rect.origin
            redLC.place(.init(origin: currentPoint, size: redResult))
            currentPoint.x += redResult.width
            nestedLC.place(.init(origin: currentPoint, size: nestedSize))
        }
    }

    let hstackSize = graph.rule(name: "hstack size") {
        return hstackLayoutComputer.wrappedValue.sizeThatFits(.init(inputSize.wrappedValue))
    }

    let childGeometries = graph.rule(name: "child geometries") {
        let lc = hstackLayoutComputer.wrappedValue
        lc.place(.init(origin: .zero, size: hstackSize.wrappedValue))
        return frames
    }

    let redGeometry = graph.rule(name: "red geometry") {
        childGeometries.wrappedValue[0]
    }

    let nestedGeometry = graph.rule(name: "nested geometry") {
        childGeometries.wrappedValue[1]
    }

    let redDisplayList = graph.rule(name: "red display list") {
        DisplayList(items: [.init(name: "red", frame: redGeometry.wrappedValue)])
    }

    let nestedDisplayList = graph.rule(name: "nested display list") {
        DisplayList(items: [.init(name: "nested", frame: nestedGeometry.wrappedValue)])
    }

    let displayList = graph.rule(name: "display list") {
        DisplayList(items: redDisplayList.wrappedValue.items + nestedDisplayList.wrappedValue.items)
    }

    var result: [GraphValue] = []
    result.append(graph.snapshot())

    let _ = displayList.wrappedValue
    result.append(graph.snapshot())

    toggleStateProp.wrappedValue.toggle()
    result.append(graph.snapshot())

    let _ = displayList.wrappedValue
    result.append(graph.snapshot())

    inputSize.wrappedValue.width = 300
    result.append(graph.snapshot())

    let _ = displayList.wrappedValue
    result.append(graph.snapshot())

    return result
}
