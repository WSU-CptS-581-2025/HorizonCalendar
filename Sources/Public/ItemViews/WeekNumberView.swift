//
//  WeekNumberView.swift
//  HorizonCalendar
//
//  Created by Cade Chaplin on 3/1/25.
//  Copyright © 2025 Airbnb. All rights reserved.
//

import UIKit

/// A view that displays a week number.
public final class WeekNumberView: UIView {
    // MARK: - Properties

    private let label: UILabel = .init()

    // MARK: - Initializers

    init(weekNumber: Int, textColor: UIColor) {
        super.init(frame: .zero)

        label.text = "\(weekNumber)"
        label.textColor = textColor
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 12, weight: .medium)

        addSubview(label)

        // Make view non-interactive so it doesn't interfere with calendar interactions
        isUserInteractionEnabled = false
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Layout

    override public func layoutSubviews() {
        super.layoutSubviews()
        label.frame = bounds
    }
}

// MARK: - CalendarItemViewRepresentable

extension WeekNumberView: CalendarItemViewRepresentable {
    /// Properties that do not change based on the state of the calendar.
    public struct InvariantViewProperties: Hashable {
        let textColor: UIColor

        public init(textColor: UIColor) {
            self.textColor = textColor
        }
    }

    /// Properties that will vary depending on the date being displayed.
    public struct Content: Equatable {
        let weekNumber: Int

        public init(weekNumber: Int) {
            self.weekNumber = weekNumber
        }
    }

    public static func makeView(withInvariantViewProperties invariantViewProperties: InvariantViewProperties) -> WeekNumberView {
        WeekNumberView(weekNumber: 0, textColor: invariantViewProperties.textColor)
    }

    public static func setContent(_ content: Content, on view: WeekNumberView) {
        view.label.text = "\(content.weekNumber)"
    }
}
