(define-constant err-no-strategy (err u400))
(define-constant err-invalid-allocation (err u401))
(define-constant err-not-owner (err u402))
(define-constant err-name-too-long (err u403))
(define-constant err-max-strategies (err u404))

(define-constant max-strategies-per-user u10)
(define-constant max-allocation u100)

(define-map strategies
    { owner: principal, strategy-id: uint }
    {
        name: (string-ascii 32),
        stx-target: uint,
        btc-target: uint,
        stable-target: uint
    }
)

(define-map user-strategy-count
    principal
    uint
)

(define-map presets
    uint
    {
        name: (string-ascii 32),
        stx-target: uint,
        btc-target: uint,
        stable-target: uint
    }
)

(define-data-var preset-count uint u3)

(begin
    (map-set presets u1 {
        name: "Conservative",
        stx-target: u20,
        btc-target: u20,
        stable-target: u60
    })
    (map-set presets u2 {
        name: "Balanced",
        stx-target: u40,
        btc-target: u30,
        stable-target: u30
    })
    (map-set presets u3 {
        name: "Aggressive",
        stx-target: u50,
        btc-target: u40,
        stable-target: u10
    })
)

(define-read-only (get-strategy (owner principal) (strategy-id uint))
    (ok (map-get? strategies { owner: owner, strategy-id: strategy-id }))
)

(define-read-only (get-user-strategy-count (user principal))
    (ok (default-to u0 (map-get? user-strategy-count user)))
)

(define-read-only (get-preset (preset-id uint))
    (ok (map-get? presets preset-id))
)

(define-read-only (get-preset-count)
    (ok (var-get preset-count))
)

(define-public (create-strategy
        (name (string-ascii 32))
        (stx-target uint)
        (btc-target uint)
        (stable-target uint)
    )
    (let
        (
            (current-count (default-to u0 (map-get? user-strategy-count tx-sender)))
            (new-id (+ current-count u1))
        )
        (asserts! (< current-count max-strategies-per-user) err-max-strategies)
        (asserts! (is-eq (+ (+ stx-target btc-target) stable-target) max-allocation) err-invalid-allocation)
        (asserts! (and (> stx-target u0) (and (> btc-target u0) (> stable-target u0))) err-invalid-allocation)
        (map-set strategies { owner: tx-sender, strategy-id: new-id } {
            name: name,
            stx-target: stx-target,
            btc-target: btc-target,
            stable-target: stable-target
        })
        (map-set user-strategy-count tx-sender new-id)
        (ok new-id)
    )
)

(define-public (delete-strategy (strategy-id uint))
    (begin
        (asserts! (is-some (map-get? strategies { owner: tx-sender, strategy-id: strategy-id })) err-no-strategy)
        (map-delete strategies { owner: tx-sender, strategy-id: strategy-id })
        (ok true)
    )
)

(define-public (apply-strategy (strategy-id uint))
    (let
        (
            (strategy (unwrap! (map-get? strategies { owner: tx-sender, strategy-id: strategy-id }) err-no-strategy))
        )
        (contract-call? .auto-portfolio-rebalancer update-targets
            (get stx-target strategy)
            (get btc-target strategy)
            (get stable-target strategy)
        )
    )
)

(define-public (apply-preset (preset-id uint))
    (let
        (
            (preset (unwrap! (map-get? presets preset-id) err-no-strategy))
        )
        (contract-call? .auto-portfolio-rebalancer update-targets
            (get stx-target preset)
            (get btc-target preset)
            (get stable-target preset)
        )
    )
)
