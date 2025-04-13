// Created by Bryan Keller on 1/15/20.
// Copyright © 2020 Airbnb Inc. All rights reserved.

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import UIKit

// MARK: - CalendarView

/// A declarative, performant calendar `UIView` that supports use cases ranging from simple date pickers all the way up to
/// fully-featured calendar apps. Its declarative API makes updating the calendar straightforward, while also providing many
/// customization points to support a diverse set of designs and use cases.
///
/// `CalendarView` does not handle any business logic related to day range selection or deselection. Instead, it provides a
/// single callback for day selection, allowing you to customize selection behavior in any way that you’d like.
///
/// Your business logic can respond to the day selection callback, regenerate `CalendarView` content based on changes to the
/// backing-models for your feature, then set the content on `CalendarView`. This will trigger `CalendarView` to re-render,
/// reflecting all new changes from the content you provide.
///
/// `CalendarView`’s content contains all information about how to render the calendar (you can think of `CalendarView` as a
/// pure function of its content). The most important things provided by the content are:
/// * The date range to display
///   * e.g. September, 2019 - April, 2020
/// * A months-layout (vertical or horizontal)
/// * An optional `CalendarItem` to display for each day in the date range if you don't want to use the default day view
///   * e.g. a view with a label representing a single day
public final class CalendarView: UIView {
    // MARK: Lifecycle

    /// Initializes a new `CalendarView` instance with the provided initial content.
    ///
    /// - Parameters:
    ///   - initialContent: The content to use when initially rendering `CalendarView`.
    public init(initialContent: CalendarViewContent) {
        content = initialContent
        super.init(frame: .zero)
        commonInit()
    }

    required init?(coder: NSCoder) {
        let startDate = Date() // now
        let endDate = Date(timeIntervalSinceNow: 31_536_000) // one year from now
        content = CalendarViewContent(visibleDateRange: startDate ... endDate, monthsLayout: .vertical)
        super.init(coder: coder)
        commonInit()
    }

    // MARK: Public

    /// A closure (that is retained) that is invoked whenever a day is selected. It is the responsibility of your feature code to decide what to
    /// do with each day. For example, you might store the most recent day in a selected day property, then read that property in your
    /// `dayItemProvider` closure to add specific "selected" styling to a particular day view.
    public var daySelectionHandler: ((Day) -> Void)?

    /// A closure (that is retained) that is invoked inside `scrollViewDidScroll(_:)`
    public var didScroll: ((_ visibleDayRange: DayComponentsRange, _ isUserDragging: Bool) -> Void)?

    /// A closure (that is retained) that is invoked inside `scrollViewDidEndDragging(_: willDecelerate:)`.
    public var didEndDragging: ((_ visibleDayRange: DayComponentsRange, _ willDecelerate: Bool) -> Void)?

    /// A closure (that is retained) that is invoked inside `scrollViewDidEndDecelerating(_:)`.
    public var didEndDecelerating: ((_ visibleDayRange: DayComponentsRange) -> Void)?

    /// A closure (that is retained) that is invoked during a multiple-selection-drag-gesture. Multiple selection is initiated with a long press,
    /// followed by a drag / pan. As the gesture crosses over more days in the calendar, this handler will be invoked with each new day. It
    /// is the responsibility of your feature code to decide what to do with this stream of days. For example, you might convert them to
    /// `Date` instances and use them as input to the `dayRangeItemProvider`.
    public var multiDaySelectionDragHandler: ((Day, UIGestureRecognizer.State) -> Void)? {
        didSet {
            configureMultiDaySelectionPanGestureRecognizer()
        }
    }

    /// Whether or not the calendar's scroll view is currently over-scrolling, i.e, whether the rubber-banding or bouncing effect is in
    /// progress.
    public var isOverScrolling: Bool {
        let scrollAxis = scrollMetricsMutator.scrollAxis
        let offset = scrollView.offset(for: scrollAxis)

        return offset < scrollView.minimumOffset(for: scrollAxis) ||
            offset > scrollView.maximumOffset(for: scrollAxis)
    }

    /// The range of months that are partially of fully visible.
    public var visibleMonthRange: MonthComponentsRange? {
        visibleItemsDetails?.visibleMonthRange
    }

    /// The range of days that are partially or fully visible.
    public var visibleDayRange: DayComponentsRange? {
        visibleItemsDetails?.visibleDayRange
    }

    /// `CalendarView` only supports positive values for `layoutMargins`. Negative values will be changed to `0`.
    override public var layoutMargins: UIEdgeInsets {
        get { super.layoutMargins }
        set {
            super.layoutMargins = UIEdgeInsets(
                top: max(newValue.top, 0),
                left: max(newValue.left, 0),
                bottom: max(newValue.bottom, 0),
                right: max(newValue.right, 0)
            )
        }
    }

    /// `CalendarView` only supports positive values for `directionalLayoutMargins`. Negative values will be changed to
    /// `0`.
    override public var directionalLayoutMargins: NSDirectionalEdgeInsets {
        get { super.directionalLayoutMargins }
        set {
            super.directionalLayoutMargins = NSDirectionalEdgeInsets(
                top: max(newValue.top, 0),
                leading: max(newValue.leading, 0),
                bottom: max(newValue.bottom, 0),
                trailing: max(newValue.trailing, 0)
            )
        }
    }

    override public func didMoveToWindow() {
        super.didMoveToWindow()

        if window == nil {
            scrollToItemContext = nil
        }
    }

    override public func layoutMarginsDidChange() {
        super.layoutMarginsDidChange()
        setNeedsLayout()
    }

    override public func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        // This can be called with a different trait collection instance, even if nothing in the trait
        // collection has changed (noticed from SwiftUI). We guard against this to prevent and
        // unnecessary layout pass.
        guard traitCollection.layoutDirection != previousTraitCollection?.layoutDirection else {
            return
        }
        setNeedsLayout()
    }

    override public func layoutSubviews() {
        super.layoutSubviews()

        // Setting the scroll view's frame in `layoutSubviews` causes over-scrolling to not work. We
        // work around this by only setting the frame if it's changed.
        if scrollView.frame != bounds {
            scrollView.frame = bounds
        }

        if traitCollection.layoutDirection == .rightToLeft {
            scrollView.transform = .init(scaleX: -1, y: 1)
        } else {
            scrollView.transform = .identity
        }

        if bounds != previousBounds || layoutMargins != previousLayoutMargins {
            maintainScrollPositionAfterBoundsOrMarginsChange()
            previousBounds = bounds
            previousLayoutMargins = layoutMargins
        }

        guard isReadyForLayout else { return }

        // Layout with an extended bounds if Voice Over is running, reducing the likelihood of a
        // Voice Over user experiencing "No heading found" when navigating by heading. We also check to
        // make sure an accessibility element has already been focused, otherwise the first
        // accessibility element will be off-screen when a user first focuses into the calendar view.
        let extendLayoutRegion = UIAccessibility.isVoiceOverRunning && initialItemViewWasFocused

        _layoutSubviews(extendLayoutRegion: extendLayoutRegion)
    }

    /// Scrolls the calendar to show today's date.
    ///
    /// If the calendar has a non-zero frame, this function will scroll to today immediately. Otherwise the scroll-to-day
    /// action will be queued and executed once the calendar has a non-zero frame.
    ///
    /// - Parameters:
    ///   - scrollPosition: The final position at which today should be situated in the scroll view.
    ///   - animated: Whether the scroll should be animated (from the current position).
    public func scrollToToday(scrollPosition: CalendarViewScrollPosition = .centered, animated: Bool = true) {
        scroll(toDayContaining: Date(), scrollPosition: scrollPosition, animated: animated)
    }

    /// Sets the content of the `CalendarView`, causing it to re-render, with no animation.
    ///
    /// - Parameters:
    ///   - content: The content to use when rendering `CalendarView`.
    public func setContent(_ content: CalendarViewContent) {
        setContent(content, animated: false)
    }

    /// Sets the content of the `CalendarView`, causing it to re-render, with an optional animation.
    ///
    /// If you call this function with `animated` set to `true` in your own animation closure, that animation will be used to perform
    /// the content update. If you call this function with `animated` set to `true` outside of an animation closure, a default animation
    /// will be used. Calling this function with `animated` set to `false` will result in a non-animated content update, even if you call
    /// it from an animation closure.
    ///
    /// - Parameters:
    ///   - content: The content to use when rendering `CalendarView`.
    ///   - animated: Whether or not the content update should be animated.
    public func setContent(_ content: CalendarViewContent, animated: Bool) {
        let oldContent = self.content

        let isInAnimationClosure = UIView.areAnimationsEnabled && UIView.inheritedAnimationDuration > 0

        // Do a preparation layout pass with an extended bounds, if we're animating. This ensures that
        // views don't pop in if they're animating in from outside the actual bounds.
        if animated {
            UIView.performWithoutAnimation {
                _layoutSubviews(extendLayoutRegion: isInAnimationClosure)
            }
        }

        _visibleItemsProvider = nil

        // We only need to clear the `scrollToItemContext` if the monthsLayout changed or the visible
        // day range changed.
        if content.monthsLayout != oldContent.monthsLayout || content.dayRange != oldContent.dayRange {
            scrollToItemContext = nil
        }

        let isAnchorLayoutItemValid: Bool = switch anchorLayoutItem?.itemType {
        case let .monthHeader(month):
            content.monthRange.contains(month)
        case let .dayOfWeekInMonth(_, month):
            content.monthRange.contains(month)
        case let .day(day):
            content.dayRange.contains(day)
        case .none:
            false
        }

        if isAnchorLayoutItemValid {
            // If we have a valid `anchorLayoutItem`, change it to be the topmost item. Normally, the
            // `anchorLayoutItem` is the centermost item, but when our content changes, it can make the
            // transition look better if our layout reference point is at the top of the screen.
            anchorLayoutItem = visibleItemsDetails?.firstLayoutItem ?? anchorLayoutItem
        } else {
            // If the `anchorLayoutItem` is no longer valid (due to it no longer being in the visible day
            // range), set it to nil. This will force us to find a new `anchorLayoutItem`.
            anchorLayoutItem = nil
        }

        if content.monthsLayout.isPaginationEnabled {
            scrollView.decelerationRate = .fast
        } else {
            scrollView.decelerationRate = .normal
        }

        if
            oldContent.monthsLayout != content.monthsLayout ||
            oldContent.monthDayInsets != content.monthDayInsets ||
            oldContent.dayAspectRatio != content.dayAspectRatio ||
            oldContent.dayOfWeekAspectRatio != content.dayOfWeekAspectRatio ||
            oldContent.horizontalDayMargin != content.horizontalDayMargin ||
            oldContent.verticalDayMargin != content.verticalDayMargin
        {
            invalidateIntrinsicContentSize()
        }

        self.content = content
        setNeedsLayout()

        // If we're animating, force layout with the inherited animation closure or with our own default
        // animation. Forcing layout ensures that frame adjustments happen with an animation.
        if animated {
            let animations = {
                self.isAnimatedUpdatePass = true
                self.layoutIfNeeded()
                self.isAnimatedUpdatePass = false
            }
            if isInAnimationClosure {
                animations()
            } else {
                UIView.animate(withDuration: 0.3, animations: animations)
            }
        }
    }

    /// Returns the accessibility element associated with the specified visible date. If the date is not currently visible, then there will be no
    /// associated accessibility element and this function will return `nil`.
    ///
    /// Use this function to programmatically change the currently-focused date via
    /// `UIAccessibility.post(notification:argument:)`, passing the returned accessibility element as the parameter for
    /// `argument`.
    ///
    /// - Parameters:
    ///   - date: The date for which to obtain an accessibility element. If the date is not currently visible, then it will not have an
    ///   associated accessibility element.
    /// - Returns: An accessibility element associated with the specified `date`, or `nil` if one cannot be found.
    public func accessibilityElementForVisibleDate(_ date: Date) -> Any? {
        let day = calendar.day(containing: date)
        guard let visibleDayRange, visibleDayRange.contains(day) else { return nil }

        for (visibleItem, visibleView) in visibleViewsForVisibleItems {
            guard case .layoutItemType(.day(day)) = visibleItem.itemType else { continue }
            return visibleView
        }

        return nil
    }

    // MARK: Internal

    lazy var doubleLayoutPassSizingLabel = DoubleLayoutPassSizingLabel(provider: self)

    var content: CalendarViewContent

    var scrollToItemContext: ScrollToItemContext? {
        willSet {
            scrollToItemDisplayLink?.invalidate()
        }
    }

    var calendar: Calendar {
        content.calendar
    }

    var scrollMetricsMutator: ScrollMetricsMutator {
        let scrollAxis: ScrollAxis = switch content.monthsLayout {
        case .vertical: .vertical
        case .horizontal: .horizontal
        }

        let scrollMetricsMutator: ScrollMetricsMutator = if let previousScrollMetricsMutator = _scrollMetricsMutator {
            if scrollAxis != previousScrollMetricsMutator.scrollAxis {
                ScrollMetricsMutator(
                    scrollMetricsProvider: scrollView,
                    scrollAxis: scrollAxis
                )
            } else {
                previousScrollMetricsMutator
            }
        } else {
            ScrollMetricsMutator(
                scrollMetricsProvider: scrollView,
                scrollAxis: scrollAxis
            )
        }

        _scrollMetricsMutator = scrollMetricsMutator

        return scrollMetricsMutator
    }

    lazy var scrollView: CalendarScrollView = {
        let scrollView = CalendarScrollView()
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.delegate = scrollViewDelegate
        return scrollView
    }()

    var scrollToItemAnimationStartTime: CFTimeInterval?

    var previousPageIndex: Int?

    lazy var multiDaySelectionLongPressGestureRecognizer: UILongPressGestureRecognizer = {
        let gestureRecognizer = UILongPressGestureRecognizer(
            target: self,
            action: #selector(multiDaySelectionGestureRecognized(_:))
        )
        gestureRecognizer.allowableMovement = .greatestFiniteMagnitude
        gestureRecognizer.delegate = gestureRecognizerDelegate
        return gestureRecognizer
    }()

    lazy var multiDaySelectionPanGestureRecognizer: UIPanGestureRecognizer = {
        let gestureRecognizer = UIPanGestureRecognizer(
            target: self,
            action: #selector(multiDaySelectionGestureRecognized(_:))
        )
        gestureRecognizer.maximumNumberOfTouches = 1
        gestureRecognizer.maximumNumberOfTouches = 1
        gestureRecognizer.delegate = gestureRecognizerDelegate
        return gestureRecognizer
    }()

    // This hack is needed to prevent the scroll view from over-scrolling far past the content. This
    // occurs in 2 scenarios:
    // - On macOS if you scroll quickly toward a boundary
    // - On iOS if you scroll quickly toward a boundary and targetContentOffset is mutated
    //
    // https://openradar.appspot.com/radar?id=4966130615582720 demonstrates this issue on macOS.
    func preventLargeOverScrollIfNeeded() {
        guard isRunningOnMac || content.monthsLayout.isPaginationEnabled else { return }

        let scrollAxis = scrollMetricsMutator.scrollAxis
        let offset = scrollView.offset(for: scrollAxis)

        let boundsSize: CGFloat = switch scrollAxis {
        case .vertical: scrollView.bounds.height * 0.7
        case .horizontal: scrollView.bounds.width * 0.7
        }

        let newOffset: CGPoint? = if offset < scrollView.minimumOffset(for: scrollAxis) - boundsSize {
            switch scrollAxis {
            case .vertical:
                CGPoint(
                    x: scrollView.contentOffset.x,
                    y: scrollView.minimumOffset(for: scrollAxis)
                )

            case .horizontal:
                CGPoint(
                    x: scrollView.minimumOffset(for: scrollAxis),
                    y: scrollView.contentOffset.y
                )
            }
        } else if offset > scrollView.maximumOffset(for: scrollAxis) + boundsSize {
            switch scrollAxis {
            case .vertical:
                CGPoint(
                    x: scrollView.contentOffset.x,
                    y: scrollView.maximumOffset(for: scrollAxis)
                )

            case .horizontal:
                CGPoint(
                    x: scrollView.maximumOffset(for: scrollAxis),
                    y: scrollView.contentOffset.y
                )
            }
        } else {
            nil
        }

        if let newOffset {
            scrollView.performWithoutNotifyingDelegate {
                // Passing `false` for `animated` is necessary to stop the in-flight deceleration animation
                UIView.animate(withDuration: 0.4, delay: 0, options: [.curveEaseOut], animations: {
                    self.scrollView.setContentOffset(newOffset, animated: false)
                })
            }
        }
    }

    // MARK: Internal

    let reuseManager = ItemViewReuseManager()
    let subviewInsertionIndexTracker = SubviewInsertionIndexTracker()

    var _scrollMetricsMutator: ScrollMetricsMutator?

    var anchorLayoutItem: LayoutItem?
    var _visibleItemsProvider: VisibleItemsProvider?
    var visibleItemsDetails: VisibleItemsDetails?
    var visibleViewsForVisibleItems = [VisibleItem: ItemView]()

    var isAnimatedUpdatePass = false

    var previousBounds = CGRect.zero
    var previousLayoutMargins = UIEdgeInsets.zero

    weak var scrollToItemDisplayLink: CADisplayLink?

    weak var autoScrollDisplayLink: CADisplayLink?
    var autoScrollOffset: CGFloat?

    var lastMultiDaySelectionDay: Day?

    lazy var scrollViewDelegate = ScrollViewDelegate(calendarView: self)
    lazy var gestureRecognizerDelegate = GestureRecognizerDelegate(calendarView: self)

    var initialItemViewWasFocused = false {
        didSet {
            guard initialItemViewWasFocused != oldValue else { return }
            setNeedsLayout()
            layoutIfNeeded()
        }
    }

    var isReadyForLayout: Bool {
        // There's no reason to attempt layout unless we have a non-zero `bounds.size`. We'll have a
        // non-zero size once the `frame` is set to something non-zero, either manually or via the
        // Auto Layout engine.
        bounds.size != .zero
    }

    var scale: CGFloat {
        let scale = traitCollection.displayScale
        // The documentation mentions that 0 is a possible value, so we guard against this.
        // It's unclear whether values between 0 and 1 are possible, otherwise `max(scale, 1)` would
        // suffice.
        return scale > 0 ? scale : 1
    }

    var visibleItemsProvider: VisibleItemsProvider {
        if
            let existingVisibleItemsProvider = _visibleItemsProvider,
            existingVisibleItemsProvider.size == bounds.size,
            existingVisibleItemsProvider.layoutMargins == directionalLayoutMargins,
            existingVisibleItemsProvider.scale == scale,
            existingVisibleItemsProvider.backgroundColor == backgroundColor
        {
            return existingVisibleItemsProvider
        } else {
            let visibleItemsProvider = VisibleItemsProvider(
                calendar: calendar,
                content: content,
                size: bounds.size,
                layoutMargins: directionalLayoutMargins,
                scale: scale,
                backgroundColor: backgroundColor
            )
            _visibleItemsProvider = visibleItemsProvider
            return visibleItemsProvider
        }
    }

    var maximumPerAnimationTickOffset: CGFloat {
        switch content.monthsLayout {
            case .vertical: bounds.height
            case .horizontal: bounds.width
        }
    }

    var firstLayoutMarginValue: CGFloat {
        switch content.monthsLayout {
            case .vertical: directionalLayoutMargins.top
            case .horizontal: directionalLayoutMargins.leading
        }
    }

    var lastLayoutMarginValue: CGFloat {
        switch content.monthsLayout {
            case .vertical: directionalLayoutMargins.bottom
            case .horizontal: directionalLayoutMargins.trailing
        }
    }

    func positionRelativeToVisibleBounds(
        for targetItem: ScrollToItemContext.TargetItem)
        -> ScrollToItemContext.PositionRelativeToVisibleBounds?
    {
        guard let visibleItemsDetails else { return nil }

        switch targetItem {
        case let .month(month):
            let monthHeaderItemType = LayoutItem.ItemType.monthHeader(month)
            if let monthFrame = visibleItemsDetails.framesForVisibleMonths[month] {
                return .partiallyOrFullyVisible(frame: monthFrame)
            } else if monthHeaderItemType < visibleItemsDetails.centermostLayoutItem.itemType {
                return .before
            } else if monthHeaderItemType > visibleItemsDetails.centermostLayoutItem.itemType {
                return .after
            } else {
                preconditionFailure("Could not find a corresponding frame for \(month).")
            }

        case let .day(day):
            let dayLayoutItemType = LayoutItem.ItemType.day(day)
            if let dayFrame = visibleItemsDetails.framesForVisibleDays[day] {
                return .partiallyOrFullyVisible(frame: dayFrame)
            } else if dayLayoutItemType < visibleItemsDetails.centermostLayoutItem.itemType {
                return .before
            } else if dayLayoutItemType > visibleItemsDetails.centermostLayoutItem.itemType {
                return .after
            } else {
                preconditionFailure("Could not find a corresponding frame for \(day).")
            }
        }
    }

    @objc
    func autoScrollDisplayLinkFired() {
        guard let autoScrollOffset else {
            fatalError("The autoScrollDisplayLink should not fire if `autoScrollOffset` is `nil`.")
        }

        scrollMetricsMutator.applyOffset(autoScrollOffset)

        if multiDaySelectionLongPressGestureRecognizer.state != .possible {
            updateSelectedDayRange(gestureRecognizer: multiDaySelectionLongPressGestureRecognizer)
        } else if multiDaySelectionPanGestureRecognizer.state != .possible {
            updateSelectedDayRange(gestureRecognizer: multiDaySelectionPanGestureRecognizer)
        } else {
            fatalError("The autoScrollDisplayLink should not fire if both gesture recognizers are in the `.possible` state.")
        }
    }

    func anchorLayoutItem(
        for scrollToItemContext: ScrollToItemContext,
        visibleItemsProvider: VisibleItemsProvider
    )
    -> LayoutItem
    {
        let offset = switch scrollMetricsMutator.scrollAxis {
            case .vertical:
                CGPoint(
                    x: scrollView.contentOffset.x + directionalLayoutMargins.leading,
                    y: scrollView.contentOffset.y
                )
            case .horizontal:
                CGPoint(
                    x: scrollView.contentOffset.x,
                    y: scrollView.contentOffset.y + directionalLayoutMargins.top
                )
        }

        switch scrollToItemContext.targetItem {
            case let .month(month):
                return visibleItemsProvider.anchorMonthHeaderItem(
                    for: month,
                    offset: offset,
                    scrollPosition: scrollToItemContext.scrollPosition
                )
            case let .day(day):
                return visibleItemsProvider.anchorDayItem(
                    for: day,
                    offset: offset,
                    scrollPosition: scrollToItemContext.scrollPosition
                )
        }
    }

    // MARK: Private

    // Necessary to work around a `UIScrollView` behavior difference on Mac. See `scrollViewDidScroll`
    // and `preventLargeOverScrollIfNeeded` for more context.
    private lazy var isRunningOnMac: Bool = {
        if #available(iOS 13.0, *) {
            if ProcessInfo.processInfo.isMacCatalystApp {
                return true
            }
        }

        return false
    }()


    private func commonInit() {
        if #available(iOS 13.0, *) {
            backgroundColor = .systemBackground
        } else {
            backgroundColor = .white
        }

        // Must be the first subview so that `UINavigationController` can monitor its scroll position
        // and make navigation bars opaque on scroll.
        insertSubview(scrollView, at: 0)

        installDoubleLayoutPassSizingLabel()

        setContent(content)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessibilityElementFocused(_:)),
            name: UIAccessibility.elementFocusedNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(setNeedsLayout),
            name: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil
        )
    }

    private func maintainScrollPositionAfterBoundsOrMarginsChange() {
        guard
            !scrollView.isDragging,
            let framesForVisibleMonths = visibleItemsDetails?.framesForVisibleMonths,
            let firstVisibleMonth = visibleMonthRange?.lowerBound,
            let frameOfFirstVisibleMonth = framesForVisibleMonths[firstVisibleMonth]
        else {
            return
        }

        let paddingFromFirstEdge: CGFloat = switch content.monthsLayout {
        case .vertical:
            frameOfFirstVisibleMonth.minY -
                scrollView.contentOffset.y -
                (visibleItemsDetails?.heightOfPinnedContent ?? 0)
        case .horizontal:
            frameOfFirstVisibleMonth.minX - scrollView.contentOffset.x
        }

        if let existingScrollToItemContext = scrollToItemContext {
            let scrollPosition: CalendarViewScrollPosition = switch existingScrollToItemContext.scrollPosition {
            case .firstFullyVisiblePosition:
                .firstFullyVisiblePosition(padding: paddingFromFirstEdge)
            default:
                existingScrollToItemContext.scrollPosition
            }

            scrollToItemContext = ScrollToItemContext(
                targetItem: existingScrollToItemContext.targetItem,
                scrollPosition: scrollPosition,
                animated: false
            )
        } else {
            scrollToItemContext = ScrollToItemContext(
                targetItem: .month(firstVisibleMonth),
                scrollPosition: .firstFullyVisiblePosition(padding: paddingFromFirstEdge),
                animated: false
            )
        }
    }

    private func configureMultiDaySelectionPanGestureRecognizer() {
        if multiDaySelectionDragHandler == nil {
            removeGestureRecognizer(multiDaySelectionLongPressGestureRecognizer)
            removeGestureRecognizer(multiDaySelectionPanGestureRecognizer)
        } else {
            addGestureRecognizer(multiDaySelectionLongPressGestureRecognizer)
            addGestureRecognizer(multiDaySelectionPanGestureRecognizer)
        }
    }

    @objc
    private func multiDaySelectionGestureRecognized(_ gestureRecognizer: UIGestureRecognizer) {
        guard gestureRecognizer.state != .possible else { return }

        // If the user interacts with the drag gesture, we should clear out any existing
        // `scrollToItemContext` that might be leftover from the initial layout process.
        scrollToItemContext = nil

        updateSelectedDayRange(gestureRecognizer: gestureRecognizer)
        updateAutoScrollingState(gestureRecognizer: gestureRecognizer)

        switch gestureRecognizer.state {
        case .ended, .cancelled, .failed:
            if let lastMultiDaySelectionDay {
                multiDaySelectionDragHandler?(lastMultiDaySelectionDay, gestureRecognizer.state)
            }
            lastMultiDaySelectionDay = nil

        default:
            break
        }
    }

    private func updateSelectedDayRange(gestureRecognizer: UIGestureRecognizer) {
        // Find the intersected day
        var intersectedDay: Day?
        for subview in scrollView.subviews {
            guard
                !subview.isHidden,
                let itemView = subview as? ItemView,
                case let .layoutItemType(.day(day)) = itemView.itemType,
                itemView.hitTest(gestureRecognizer.location(in: itemView), with: nil) != nil
            else {
                continue
            }
            intersectedDay = day
            break
        }

        if let intersectedDay, intersectedDay != lastMultiDaySelectionDay {
            lastMultiDaySelectionDay = intersectedDay
            multiDaySelectionDragHandler?(intersectedDay, gestureRecognizer.state)
        } else if gestureRecognizer.state == .began {
            // If the gesture doesn't intersect a day in the `began` state, cancel it
            gestureRecognizer.isEnabled = false
            gestureRecognizer.isEnabled = true
        }
    }
}

// MARK: WidthDependentIntrinsicContentHeightProviding

extension CalendarView: WidthDependentIntrinsicContentHeightProviding {
    // This is where we perform our width-dependent height calculation. See `DoubleLayoutPassHelpers`
    // for more details about why this is needed and how it works.
    func intrinsicContentSize(forHorizontallyInsetWidth width: CGFloat) -> CGSize {
        let calendarWidth = width + layoutMargins.left + layoutMargins.right
        let calendarHeight: CGFloat = if content.monthsLayout.isHorizontal {
            .maxLayoutValue
        } else {
            bounds.height
        }

        let visibleItemsProvider = VisibleItemsProvider(
            calendar: calendar,
            content: content,
            size: CGSize(width: calendarWidth, height: calendarHeight),
            layoutMargins: directionalLayoutMargins,
            scale: scale,
            backgroundColor: backgroundColor
        )

        let anchorMonthHeaderLayoutItem = anchorLayoutItem(
            for: .init(
                targetItem: .month(content.monthRange.lowerBound),
                scrollPosition: .firstFullyVisiblePosition,
                animated: false
            ),
            visibleItemsProvider: visibleItemsProvider
        )

        let visibleItemsDetails = visibleItemsProvider.detailsForVisibleItems(
            surroundingPreviouslyVisibleLayoutItem: anchorMonthHeaderLayoutItem,
            offset: scrollView.contentOffset,
            extendLayoutRegion: false
        )

        return CGSize(width: UIView.noIntrinsicMetric, height: visibleItemsDetails.intrinsicHeight)
    }
}

// MARK: `UIResponder` Next `ItemView`

extension UIResponder {
    func nextItemView() -> ItemView? {
        self as? ItemView ?? next?.nextItemView()
    }
}
