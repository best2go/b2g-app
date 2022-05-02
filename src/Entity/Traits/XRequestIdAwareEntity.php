<?php declare(strict_types=1);

namespace App\Entity\Traits;

use Doctrine\ORM\Mapping as ORM;

trait XRequestIdAwareEntity
{
    /**
     * @var string|null
     * @ORM\Column(name="x_request_id", type="string", length=64, nullable=true)
     */
    private $xRequestId;

    public function getXRequestId(): ?string
    {
        return $this->xRequestId;
    }

    public function setXRequestId(?string $xRequestId): void
    {
        $this->xRequestId = $xRequestId;
    }
}
