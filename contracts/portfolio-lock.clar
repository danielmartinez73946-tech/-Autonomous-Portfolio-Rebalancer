(define-constant err-already-locked (err u700))
(define-constant err-not-locked (err u701))
(define-constant err-lock-active (err u702))
(define-constant err-invalid-duration (err u703))
(define-constant err-no-portfolio (err u704))

(define-constant min-lock-duration u144)
(define-constant max-lock-duration u52560)

(define-map portfolio-locks
    principal
    {
        lock-until: uint,
        locked-at: uint
    }
)

(define-read-only (is-locked (user principal))
    (match (map-get? portfolio-locks user)
        lock-data (< stacks-block-height (get lock-until lock-data))
        false
    )
)

(define-read-only (get-lock-info (user principal))
    (ok (map-get? portfolio-locks user))
)

(define-read-only (blocks-remaining (user principal))
    (match (map-get? portfolio-locks user)
        lock-data
        (if (< stacks-block-height (get lock-until lock-data))
            (ok (- (get lock-until lock-data) stacks-block-height))
            (ok u0)
        )
        (ok u0)
    )
)

(define-public (lock-portfolio (duration uint))
    (begin
        (asserts! (not (is-locked tx-sender)) err-already-locked)
        (asserts! (>= duration min-lock-duration) err-invalid-duration)
        (asserts! (<= duration max-lock-duration) err-invalid-duration)
        (map-set portfolio-locks tx-sender {
            lock-until: (+ stacks-block-height duration),
            locked-at: stacks-block-height
        })
        (ok true)
    )
)

(define-public (extend-lock (additional-blocks uint))
    (let
        (
            (lock-data (unwrap! (map-get? portfolio-locks tx-sender) err-not-locked))
            (current-until (get lock-until lock-data))
            (new-until (+ current-until additional-blocks))
        )
        (asserts! (is-locked tx-sender) err-not-locked)
        (asserts! (> additional-blocks u0) err-invalid-duration)
        (asserts! (<= (- new-until stacks-block-height) max-lock-duration) err-invalid-duration)
        (map-set portfolio-locks tx-sender
            (merge lock-data { lock-until: new-until })
        )
        (ok true)
    )
)

(define-public (unlock-portfolio)
    (begin
        (asserts! (is-some (map-get? portfolio-locks tx-sender)) err-not-locked)
        (asserts! (not (is-locked tx-sender)) err-lock-active)
        (map-delete portfolio-locks tx-sender)
        (ok true)
    )
)
