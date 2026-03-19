(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u600))
(define-constant err-already-paused (err u601))
(define-constant err-not-paused (err u602))
(define-constant err-cooldown-active (err u603))
(define-constant err-protocol-paused (err u604))

(define-constant cooldown-blocks u144)

(define-data-var paused bool false)
(define-data-var pause-block uint u0)
(define-data-var unpause-block uint u0)
(define-data-var pause-count uint u0)

(define-read-only (is-paused)
    (var-get paused)
)

(define-read-only (get-pause-info)
    (ok {
        paused: (var-get paused),
        pause-block: (var-get pause-block),
        unpause-block: (var-get unpause-block),
        pause-count: (var-get pause-count)
    })
)

(define-read-only (blocks-until-cooldown-expires)
    (let
        (
            (last-unpause (var-get unpause-block))
            (cooldown-end (+ last-unpause cooldown-blocks))
        )
        (if (or (is-eq last-unpause u0) (>= stacks-block-height cooldown-end))
            u0
            (- cooldown-end stacks-block-height)
        )
    )
)

(define-public (pause)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (not (var-get paused)) err-already-paused)
        (var-set paused true)
        (var-set pause-block stacks-block-height)
        (var-set pause-count (+ (var-get pause-count) u1))
        (ok true)
    )
)

(define-public (unpause)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (var-get paused) err-not-paused)
        (var-set paused false)
        (var-set unpause-block stacks-block-height)
        (ok true)
    )
)

(define-public (assert-not-paused)
    (begin
        (asserts! (not (var-get paused)) err-protocol-paused)
        (ok true)
    )
)
